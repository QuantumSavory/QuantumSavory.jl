using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, timeout, run

SUITE["register_locks"] = BenchmarkGroup(["register_locks"])

@resumable function _register_lock_holder(sim, slot, hold_time)
    @yield lock(slot)
    @yield timeout(sim, hold_time)
    unlock(slot)
end

@resumable function _register_lock_waiter(sim, slot, start_delay)
    if start_delay > 0
        @yield timeout(sim, start_delay)
    end
    @yield lock(slot)
    unlock(slot)
end

@resumable function _register_lock_reduce_worker(sim, slots)
    @yield reduce(&, [lock(slot) for slot in slots])
    foreach(unlock, slots)
end

@resumable function _register_lock_nongreedy_worker(sim, slots, start_delay)
    if start_delay > 0
        @yield timeout(sim, start_delay)
    end
    @yield ConcurrentSim.Process(nongreedymultilock, sim, slots)
    foreach(unlock, slots)
end

@resumable function _register_lock_spin_worker(sim, slots, period, start_delay)
    if start_delay > 0
        @yield timeout(sim, start_delay)
    end
    @yield ConcurrentSim.Process(spinlock, sim, slots, period; randomize=false)
    foreach(unlock, slots)
end

function prepare_register_lock_contention(; n_waiters::Int, hold_time::Float64=1.0)
    reg = Register(1)
    sim = get_time_tracker(reg)

    @process _register_lock_holder(sim, reg[1], hold_time)
    for _ in 1:n_waiters
        @process _register_lock_waiter(sim, reg[1], 0.001)
    end

    return sim
end

function prepare_register_multilock(; n_slots::Int, mode::Symbol)
    reg = Register(n_slots)
    sim = get_time_tracker(reg)
    slots = [reg[i] for i in 1:n_slots]

    if mode === :reduce
        @process _register_lock_reduce_worker(sim, slots)
    elseif mode === :nongreedy
        @process _register_lock_nongreedy_worker(sim, slots, 0.0)
    elseif mode === :spin
        @process _register_lock_spin_worker(sim, slots, 1.0, 0.0)
    else
        throw(ArgumentError("unknown register lock mode: $mode"))
    end

    return sim
end

function prepare_register_multilock_contention(; n_slots::Int, mode::Symbol, hold_time::Float64=1.0)
    reg = Register(n_slots)
    sim = get_time_tracker(reg)
    slots = [reg[i] for i in 1:n_slots]

    @process _register_lock_holder(sim, first(slots), hold_time)
    if mode === :nongreedy
        @process _register_lock_nongreedy_worker(sim, slots, 0.001)
    elseif mode === :spin
        @process _register_lock_spin_worker(sim, slots, 0.25, 0.001)
    else
        throw(ArgumentError("unknown contended register lock mode: $mode"))
    end

    return sim
end

SUITE["register_locks"]["api"] = BenchmarkGroup(["api"])
SUITE["register_locks"]["api"]["islocked_unlocked"] = @benchmarkable islocked(slot) setup=(reg = Register(1); slot = reg[1])
SUITE["register_locks"]["api"]["lock_unlock_single"] = @benchmarkable begin
    lock(slot)
    unlock(slot)
end setup=(reg = Register(1); slot = reg[1]) evals=1

SUITE["register_locks"]["single_slot_contention"] = BenchmarkGroup(["single_slot_contention"])
for n_waiters in (1, 8, 64, 256)
    label = "waiters_$(n_waiters)"
    SUITE["register_locks"]["single_slot_contention"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_lock_contention(; n_waiters=$n_waiters)) evals=1
end

SUITE["register_locks"]["multi_slot"] = BenchmarkGroup(["multi_slot"])
for n_slots in (2, 8, 32)
    label = "slots_$(n_slots)_reduce"
    SUITE["register_locks"]["multi_slot"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_multilock(; n_slots=$n_slots, mode=:reduce)) evals=1
end
for n_slots in (2, 8, 32)
    label = "slots_$(n_slots)_nongreedy"
    SUITE["register_locks"]["multi_slot"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_multilock(; n_slots=$n_slots, mode=:nongreedy)) evals=1
end
for n_slots in (2, 8, 32)
    label = "slots_$(n_slots)_spin"
    SUITE["register_locks"]["multi_slot"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_multilock(; n_slots=$n_slots, mode=:spin)) evals=1
end

SUITE["register_locks"]["multi_slot_contention"] = BenchmarkGroup(["multi_slot_contention"])
for n_slots in (2, 8, 32)
    label = "slots_$(n_slots)_nongreedy"
    SUITE["register_locks"]["multi_slot_contention"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_multilock_contention(; n_slots=$n_slots, mode=:nongreedy)) evals=1
end
for n_slots in (2, 8, 32)
    label = "slots_$(n_slots)_spin"
    SUITE["register_locks"]["multi_slot_contention"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_multilock_contention(; n_slots=$n_slots, mode=:spin)) evals=1
end
