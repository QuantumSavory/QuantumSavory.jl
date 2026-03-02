using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, timeout, run

SUITE["onchange"] = BenchmarkGroup(["onchange"])

# These benchmarks isolate the scheduling/wakeup cost of waiting on
# `onchange(..., Tag)` while varying writer/waiter concurrency.
# Each benchmark prepares a fresh simulation in setup and then measures `run(sim)`.
# We keep finite loops and match produced tags to waits so the simulation terminates.

function _wait_targets(total_events::Int, n_waiters::Int)
    waits = fill(div(total_events, n_waiters), n_waiters)
    remainder = rem(total_events, n_waiters)
    for i in 1:remainder
        waits[i] += 1
    end
    return waits
end

@resumable function _onchange_writer(sim, reg, tagsymbol, writer_id, events)
    # Small phase offsets avoid synchronized bursts from all writers.
    @yield timeout(sim, 0.001 * writer_id)
    for event_id in 1:events
        @yield timeout(sim, 1.0)
        tag!(reg[1], tagsymbol, writer_id, event_id)
    end
end

@resumable function _onchange_waiter(sim, target, nwaits)
    for _ in 1:nwaits
        @yield onchange(target, Tag)
    end
end

@resumable function _onchange_mb_writer_direct(sim, mb, tagsymbol, writer_id, events)
    @yield timeout(sim, 0.001 * writer_id)
    for event_id in 1:events
        @yield timeout(sim, 1.0)
        put!(mb, Tag(tagsymbol, writer_id, event_id))
    end
end

@resumable function _onchange_mb_writer_channel(sim, ch, tagsymbol, writer_id, events)
    @yield timeout(sim, 0.001 * writer_id)
    for event_id in 1:events
        @yield timeout(sim, 1.0)
        put!(ch, Tag(tagsymbol, writer_id, event_id))
    end
end

@resumable function _onchange_mb_waiter_any(sim, mb1, mb2, nwaits)
    for _ in 1:nwaits
        # Pattern used in tests: wait for whichever buffer changes first.
        p1 = onchange(mb1, Tag)
        p2 = onchange(mb2, Tag)
        @yield (p1 | p2)
    end
end

function prepare_onchange_shared_register(; n_writers::Int, n_waiters::Int, events_per_writer::Int, wait_on_regref::Bool)
    net = RegisterNet([Register(1)])
    sim = get_time_tracker(net)
    reg = net[1]
    target = wait_on_regref ? reg[1] : reg

    total_events = n_writers * events_per_writer
    waits_per_waiter = _wait_targets(total_events, n_waiters)

    for writer_id in 1:n_writers
        @process _onchange_writer(sim, reg, :bench_onchange, writer_id, events_per_writer)
    end
    for nwaits in waits_per_waiter
        @process _onchange_waiter(sim, target, nwaits)
    end

    return sim
end

function prepare_onchange_sharded_registers(; n_pairs::Int, events_per_writer::Int, wait_on_regref::Bool)
    net = RegisterNet([Register(1) for _ in 1:n_pairs])
    sim = get_time_tracker(net)

    for i in 1:n_pairs
        reg = net[i]
        target = wait_on_regref ? reg[1] : reg
        @process _onchange_writer(sim, reg, :bench_onchange_shard, i, events_per_writer)
        @process _onchange_waiter(sim, target, events_per_writer)
    end

    return sim
end

function prepare_onchange_shared_messagebuffer_direct(; n_writers::Int, n_waiters::Int, events_per_writer::Int)
    net = RegisterNet([Register(1)])
    sim = get_time_tracker(net)
    mb = messagebuffer(net[1])

    total_events = n_writers * events_per_writer
    waits_per_waiter = _wait_targets(total_events, n_waiters)

    for writer_id in 1:n_writers
        @process _onchange_mb_writer_direct(sim, mb, :bench_onchange_mb_direct, writer_id, events_per_writer)
    end
    for nwaits in waits_per_waiter
        @process _onchange_waiter(sim, mb, nwaits)
    end

    return sim
end

function prepare_onchange_shared_messagebuffer_channel(; n_writers::Int, n_waiters::Int, events_per_writer::Int)
    # Two-node net (source->destination) to include channel + take_loop_mb path.
    net = RegisterNet([Register(1), Register(1)], classical_delay=1.0, quantum_delay=1.0)
    sim = get_time_tracker(net)
    mb = messagebuffer(net[1])
    ch = channel(net, 2 => 1)

    total_events = n_writers * events_per_writer
    waits_per_waiter = _wait_targets(total_events, n_waiters)

    for writer_id in 1:n_writers
        @process _onchange_mb_writer_channel(sim, ch, :bench_onchange_mb_channel, writer_id, events_per_writer)
    end
    for nwaits in waits_per_waiter
        @process _onchange_waiter(sim, mb, nwaits)
    end

    return sim
end

function prepare_onchange_dual_messagebuffer_any(; n_writers::Int, n_waiters::Int, events_per_writer::Int)
    # Mirrors the "wait on either message buffer" test pattern.
    net = RegisterNet([Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    mb1 = messagebuffer(net[1])
    mb2 = messagebuffer(net[2])

    total_events = n_writers * events_per_writer
    waits_per_waiter = _wait_targets(total_events, n_waiters)

    for writer_id in 1:n_writers
        mb = isodd(writer_id) ? mb1 : mb2
        @process _onchange_mb_writer_direct(sim, mb, :bench_onchange_mb_any, writer_id, events_per_writer)
    end
    for nwaits in waits_per_waiter
        @process _onchange_mb_waiter_any(sim, mb1, mb2, nwaits)
    end

    return sim
end

SUITE["onchange"]["shared_register"] = BenchmarkGroup(["shared_register"])
# Contended waiters/writers on a single register (most direct stress test).
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4), (2, 16), (16, 2))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["onchange"]["shared_register"][label] = @benchmarkable run(sim) setup=(sim = prepare_onchange_shared_register(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=32, wait_on_regref=false)) evals=1
end

SUITE["onchange"]["shared_regref"] = BenchmarkGroup(["shared_regref"])
# Same contention pattern, but waiting on `RegRef` rather than `Register`.
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["onchange"]["shared_regref"][label] = @benchmarkable run(sim) setup=(sim = prepare_onchange_shared_register(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=32, wait_on_regref=true)) evals=1
end

SUITE["onchange"]["sharded_registers"] = BenchmarkGroup(["sharded_registers"])
# One writer/one waiter per register, scaling number of independent register waiters.
for n_pairs in (1, 4, 16, 32)
    label = "pairs_$(n_pairs)"
    SUITE["onchange"]["sharded_registers"][label] = @benchmarkable run(sim) setup=(sim = prepare_onchange_sharded_registers(; n_pairs=$n_pairs, events_per_writer=32, wait_on_regref=false)) evals=1
end

SUITE["onchange"]["shared_messagebuffer_direct"] = BenchmarkGroup(["shared_messagebuffer_direct"])
# Contention on a single MessageBuffer with direct `put!` writers.
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4), (2, 16), (16, 2))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["onchange"]["shared_messagebuffer_direct"][label] = @benchmarkable run(sim) setup=(sim = prepare_onchange_shared_messagebuffer_direct(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=16)) evals=1
end

SUITE["onchange"]["shared_messagebuffer_channel"] = BenchmarkGroup(["shared_messagebuffer_channel"])
# Same pattern, but writing via `channel(...); put!(ch, Tag(...))` to include transport path.
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["onchange"]["shared_messagebuffer_channel"][label] = @benchmarkable run(sim) setup=(sim = prepare_onchange_shared_messagebuffer_channel(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=16)) evals=1
end

SUITE["onchange"]["dual_messagebuffer_any"] = BenchmarkGroup(["dual_messagebuffer_any"])
# Receiver-style pattern from tests: each waiter yields on `onchange(mb1, Tag) | onchange(mb2, Tag)`.
for (n_writers, n_waiters) in ((2, 1), (4, 1), (4, 4), (8, 4))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["onchange"]["dual_messagebuffer_any"][label] = @benchmarkable run(sim) setup=(sim = prepare_onchange_dual_messagebuffer_any(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=16)) evals=1
end
