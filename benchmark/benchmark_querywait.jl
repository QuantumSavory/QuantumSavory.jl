using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, timeout, run

SUITE["querywait"] = BenchmarkGroup(["querywait"])

# These benchmarks measure the combined cost of waiting (onchange) and querying
# that `query_wait` / `querydelete_wait!` encapsulate.
# Each benchmark prepares a fresh simulation in setup and then measures `run(sim)`.

# -- Register benchmarks --

@resumable function _querywait_writer(sim, reg, tagsymbol, writer_id, events)
    @yield timeout(sim, 0.001 * writer_id)
    for event_id in 1:events
        @yield timeout(sim, 1.0)
        tag!(reg[1], tagsymbol, writer_id, event_id)
    end
end

@resumable function _querywait_waiter(sim, reg, tagsymbol, nwaits)
    for _ in 1:nwaits
        result = @yield query_wait(reg, tagsymbol, ❓, ❓)
        # consume the tag so next iteration waits again
        untag!(reg, result.id)
    end
end

@resumable function _querydelete_wait_reg_waiter(sim, reg, tagsymbol, nwaits)
    for _ in 1:nwaits
        result = @yield querydelete_wait!(reg, tagsymbol, ❓, ❓)
    end
end

function prepare_querywait_register(; n_writers::Int, n_waiters::Int, events_per_writer::Int, use_querydelete::Bool=false)
    net = RegisterNet([Register(1)])
    sim = get_time_tracker(net)
    reg = net[1]

    total_events = n_writers * events_per_writer
    waits = fill(div(total_events, n_waiters), n_waiters)
    remainder = rem(total_events, n_waiters)
    for i in 1:remainder
        waits[i] += 1
    end

    for writer_id in 1:n_writers
        @process _querywait_writer(sim, reg, :bench_qw, writer_id, events_per_writer)
    end
    for nw in waits
        if use_querydelete
            @process _querydelete_wait_reg_waiter(sim, reg, :bench_qw, nw)
        else
            @process _querywait_waiter(sim, reg, :bench_qw, nw)
        end
    end

    return sim
end

# -- MessageBuffer benchmarks --

@resumable function _querywait_mb_writer(sim, mb, tagsymbol, writer_id, events)
    @yield timeout(sim, 0.001 * writer_id)
    for event_id in 1:events
        @yield timeout(sim, 1.0)
        put!(mb, Tag(tagsymbol, writer_id, event_id))
    end
end

@resumable function _querywait_mb_waiter(sim, mb, tagsymbol, nwaits)
    for _ in 1:nwaits
        result = @yield querydelete_wait!(mb, tagsymbol, ❓, ❓)
    end
end

function prepare_querywait_messagebuffer(; n_writers::Int, n_waiters::Int, events_per_writer::Int)
    net = RegisterNet([Register(1)])
    sim = get_time_tracker(net)
    mb = messagebuffer(net[1])

    total_events = n_writers * events_per_writer
    waits = fill(div(total_events, n_waiters), n_waiters)
    remainder = rem(total_events, n_waiters)
    for i in 1:remainder
        waits[i] += 1
    end

    for writer_id in 1:n_writers
        @process _querywait_mb_writer(sim, mb, :bench_qw_mb, writer_id, events_per_writer)
    end
    for nw in waits
        @process _querywait_mb_waiter(sim, mb, :bench_qw_mb, nw)
    end

    return sim
end

# -- MessageBuffer via channel (includes transport path) --

@resumable function _querywait_mb_channel_writer(sim, ch, tagsymbol, writer_id, events)
    @yield timeout(sim, 0.001 * writer_id)
    for event_id in 1:events
        @yield timeout(sim, 1.0)
        put!(ch, Tag(tagsymbol, writer_id, event_id))
    end
end

function prepare_querywait_messagebuffer_channel(; n_writers::Int, n_waiters::Int, events_per_writer::Int)
    net = RegisterNet([Register(1), Register(1)], classical_delay=1.0, quantum_delay=1.0)
    sim = get_time_tracker(net)
    mb = messagebuffer(net[1])
    ch = channel(net, 2 => 1)

    total_events = n_writers * events_per_writer
    waits = fill(div(total_events, n_waiters), n_waiters)
    remainder = rem(total_events, n_waiters)
    for i in 1:remainder
        waits[i] += 1
    end

    for writer_id in 1:n_writers
        @process _querywait_mb_channel_writer(sim, ch, :bench_qw_mb_ch, writer_id, events_per_writer)
    end
    for nw in waits
        @process _querywait_mb_waiter(sim, mb, :bench_qw_mb_ch, nw)
    end

    return sim
end

# Register: query_wait (query + untag)
SUITE["querywait"]["register_query_wait"] = BenchmarkGroup(["register_query_wait"])
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["querywait"]["register_query_wait"][label] = @benchmarkable run(sim) setup=(sim = prepare_querywait_register(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=16, use_querydelete=false)) evals=1
end

# Register: querydelete_wait!
SUITE["querywait"]["register_querydelete_wait"] = BenchmarkGroup(["register_querydelete_wait"])
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["querywait"]["register_querydelete_wait"][label] = @benchmarkable run(sim) setup=(sim = prepare_querywait_register(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=16, use_querydelete=true)) evals=1
end

# MessageBuffer: querydelete_wait! (direct put!)
SUITE["querywait"]["messagebuffer_direct"] = BenchmarkGroup(["messagebuffer_direct"])
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["querywait"]["messagebuffer_direct"][label] = @benchmarkable run(sim) setup=(sim = prepare_querywait_messagebuffer(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=16)) evals=1
end

# MessageBuffer: querydelete_wait! via channel (includes transport delay)
SUITE["querywait"]["messagebuffer_channel"] = BenchmarkGroup(["messagebuffer_channel"])
for (n_writers, n_waiters) in ((1, 1), (1, 8), (8, 1), (4, 4))
    label = "writers_$(n_writers)_waiters_$(n_waiters)"
    SUITE["querywait"]["messagebuffer_channel"][label] = @benchmarkable run(sim) setup=(sim = prepare_querywait_messagebuffer_channel(; n_writers=$n_writers, n_waiters=$n_waiters, events_per_writer=16)) evals=1
end
