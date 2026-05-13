using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, request, run

SUITE["locks"] = BenchmarkGroup(["locks"])
SUITE["channels"] = BenchmarkGroup(["channels"])

@resumable function _slot_lock_worker(sim, slot, rounds)
    for _ in 1:rounds
        @yield request(slot)
        unlock(slot)
    end
end

function prepare_slot_lock_sim(; n_slots::Int, n_workers::Int, rounds::Int)
    net = RegisterNet([Register(n_slots)])
    sim = get_time_tracker(net)
    for worker in 1:n_workers
        slot = net[1][mod1(worker, n_slots)]
        @process _slot_lock_worker(sim, slot, rounds)
    end
    return sim
end

SUITE["locks"]["regref"] = BenchmarkGroup(["regref"])
SUITE["locks"]["regref"]["islocked_unlocked"] =
    @benchmarkable islocked(slot) setup=(reg = Register(1); slot = reg[1])
SUITE["locks"]["regref"]["single_slot_uncontended"] =
    @benchmarkable run(sim) setup=(sim = prepare_slot_lock_sim(; n_slots=1, n_workers=1, rounds=64)) evals=1
SUITE["locks"]["regref"]["single_slot_contended"] =
    @benchmarkable run(sim) setup=(sim = prepare_slot_lock_sim(; n_slots=1, n_workers=8, rounds=16)) evals=1
SUITE["locks"]["regref"]["many_slots_parallel"] =
    @benchmarkable run(sim) setup=(sim = prepare_slot_lock_sim(; n_slots=8, n_workers=8, rounds=16)) evals=1

@resumable function _classical_channel_sender(sim, ch, n_messages)
    for i in 1:n_messages
        put!(ch, Tag(:bench_channel, i))
    end
end

@resumable function _classical_channel_receiver(sim, mb, n_messages)
    for i in 1:n_messages
        @yield querydelete_wait!(mb, :bench_channel, i)
    end
end

function prepare_classical_channel_sim(; n_messages::Int)
    net = RegisterNet([Register(1), Register(1)], classical_delay=1.0, quantum_delay=1.0)
    sim = get_time_tracker(net)
    ch = channel(net, 1 => 2)
    mb = messagebuffer(net[2])

    @process _classical_channel_sender(sim, ch, n_messages)
    @process _classical_channel_receiver(sim, mb, n_messages)

    return sim
end

const _locks_channels_bell = StabilizerState("XX ZZ")

@resumable function _quantum_channel_sender(sim, qc, slots)
    for slot in slots
        put!(qc, slot)
    end
end

@resumable function _quantum_channel_receiver(sim, qc, slots)
    for slot in slots
        @yield take!(qc, slot)
    end
end

function prepare_quantum_channel_sim(; n_pairs::Int)
    sim = Simulation()
    reg_a = Register(n_pairs)
    reg_b = Register(2 * n_pairs)
    for i in 1:n_pairs
        initialize!((reg_a[i], reg_b[n_pairs + i]), _locks_channels_bell)
    end
    qc = QuantumChannel(sim, 1.0)

    @process _quantum_channel_sender(sim, qc, [reg_a[i] for i in 1:n_pairs])
    @process _quantum_channel_receiver(sim, qc, [reg_b[i] for i in 1:n_pairs])

    return sim
end

SUITE["channels"]["classical"] = BenchmarkGroup(["classical"])
for n_messages in (1, 16, 64)
    SUITE["channels"]["classical"]["messages_$(n_messages)"] =
        @benchmarkable run(sim) setup=(sim = prepare_classical_channel_sim(; n_messages=$n_messages)) evals=1
end

SUITE["channels"]["quantum"] = BenchmarkGroup(["quantum"])
for n_pairs in (1, 4, 16)
    SUITE["channels"]["quantum"]["transfers_$(n_pairs)"] =
        @benchmarkable run(sim) setup=(sim = prepare_quantum_channel_sim(; n_pairs=$n_pairs)) evals=1
end
