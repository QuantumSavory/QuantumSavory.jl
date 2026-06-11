using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, timeout, run, now, Simulation

SUITE["locks_channels"] = BenchmarkGroup(["locks_channels"])

# Lock benchmarks are grouped separately from tags/queries because slot locks
# are simulator resources; the measured work happens when `run(sim)` executes.
@resumable function _lock_single_slot_worker(sim, slot, rounds)
    for _ in 1:rounds
        @yield lock(slot)
        unlock(slot)
        @yield timeout(sim, 0.0)
    end
end

@resumable function _lock_pair_worker(sim, slot_a, slot_b, rounds)
    for _ in 1:rounds
        @yield lock(slot_a) & lock(slot_b)
        unlock(slot_a)
        unlock(slot_b)
        @yield timeout(sim, 0.0)
    end
end

@resumable function _spinlock_pair_worker(sim, slots, rounds)
    for _ in 1:rounds
        @yield spinlock(sim, slots, 0.001; randomize=false)
        unlock.(slots)
        @yield timeout(sim, 0.0)
    end
end

function prepare_single_slot_lock_sim(; nworkers::Int, rounds::Int)
    net = RegisterNet([Register(1)])
    sim = get_time_tracker(net)
    slot = net[1, 1]
    for _ in 1:nworkers
        @process _lock_single_slot_worker(sim, slot, rounds)
    end
    return sim
end

function prepare_pair_lock_sim(; nworkers::Int, rounds::Int, use_spinlock::Bool=false)
    net = RegisterNet([Register(2)])
    sim = get_time_tracker(net)
    slots = [net[1, 1], net[1, 2]]
    for _ in 1:nworkers
        if use_spinlock
            @process _spinlock_pair_worker(sim, slots, rounds)
        else
            @process _lock_pair_worker(sim, slots[1], slots[2], rounds)
        end
    end
    return sim
end

SUITE["locks_channels"]["locks"] = BenchmarkGroup(["locks"])
SUITE["locks_channels"]["locks"]["single_slot_uncontended"] = @benchmarkable run(sim) setup=(sim = prepare_single_slot_lock_sim(; nworkers=1, rounds=128)) evals=1
SUITE["locks_channels"]["locks"]["single_slot_contended"] = @benchmarkable run(sim) setup=(sim = prepare_single_slot_lock_sim(; nworkers=16, rounds=32)) evals=1
SUITE["locks_channels"]["locks"]["pair_lock_uncontended"] = @benchmarkable run(sim) setup=(sim = prepare_pair_lock_sim(; nworkers=1, rounds=128)) evals=1
SUITE["locks_channels"]["locks"]["pair_lock_contended"] = @benchmarkable run(sim) setup=(sim = prepare_pair_lock_sim(; nworkers=16, rounds=32)) evals=1
SUITE["locks_channels"]["locks"]["spinlock_pair_contended"] = @benchmarkable run(sim) setup=(sim = prepare_pair_lock_sim(; nworkers=16, rounds=32, use_spinlock=true)) evals=1

# Channel benchmarks cover both classical Tag transport and quantum-state
# transport, including the delayed events that deliver into buffers/registers.
@resumable function _classical_channel_sender(sim, ch, ntags)
    for i in 1:ntags
        put!(ch, Tag(:bench_channel, i, i + 1))
        @yield timeout(sim, 0.0)
    end
end

function prepare_classical_channel_sim(; ntags::Int, delay=1.0)
    net = RegisterNet([Register(1), Register(1)], classical_delay=delay)
    sim = get_time_tracker(net)
    ch = channel(net, 1 => 2)
    @process _classical_channel_sender(sim, ch, ntags)
    return sim
end

@resumable function _quantum_channel_sender(sim, qc, src, npairs)
    for _ in 1:npairs
        initialize!(src[1], X1; time=now(sim))
        put!(qc, src[1])
        @yield timeout(sim, 1.0)
    end
end

@resumable function _quantum_channel_receiver(sim, qc, dst, npairs)
    for _ in 1:npairs
        @yield take!(qc, dst[1])
        project_traceout!(dst[1], Z; time=now(sim))
    end
end

function prepare_quantum_channel_sim(; npairs::Int, delay=1.0, background=nothing)
    sim = Simulation()
    src = Register([Qubit()], [QuantumOpticsRepr()], [nothing])
    dst = Register([Qubit()], [QuantumOpticsRepr()], [nothing])
    qc = QuantumChannel(sim, delay, background)
    @process _quantum_channel_sender(sim, qc, src, npairs)
    @process _quantum_channel_receiver(sim, qc, dst, npairs)
    return sim
end

SUITE["locks_channels"]["classical_channel"] = BenchmarkGroup(["classical_channel"])
SUITE["locks_channels"]["classical_channel"]["send_tags_small"] = @benchmarkable run(sim) setup=(sim = prepare_classical_channel_sim(; ntags=16)) evals=1
SUITE["locks_channels"]["classical_channel"]["send_tags_large"] = @benchmarkable run(sim) setup=(sim = prepare_classical_channel_sim(; ntags=1024)) evals=1

SUITE["locks_channels"]["quantum_channel"] = BenchmarkGroup(["quantum_channel"])
SUITE["locks_channels"]["quantum_channel"]["send_qubits_small"] = @benchmarkable run(sim) setup=(sim = prepare_quantum_channel_sim(; npairs=16)) evals=1
SUITE["locks_channels"]["quantum_channel"]["send_qubits_large"] = @benchmarkable run(sim) setup=(sim = prepare_quantum_channel_sim(; npairs=128)) evals=1
SUITE["locks_channels"]["quantum_channel"]["send_qubits_t2_background"] = @benchmarkable run(sim) setup=(sim = prepare_quantum_channel_sim(; npairs=64, background=T2Dephasing(10.0))) evals=1
