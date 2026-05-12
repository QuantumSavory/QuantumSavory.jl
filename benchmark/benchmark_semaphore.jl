using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, timeout, run

SUITE["change_notifier"] = BenchmarkGroup(["change_notifier"])

@resumable function _change_notifier_broadcast_trigger(sim, notifier, rounds)
    for _ in 1:rounds
        @yield timeout(sim, 1.0)
        unlock(notifier)
    end
end

@resumable function _change_notifier_waiter(sim, notifier, rounds)
    for _ in 1:rounds
        @yield lock(notifier)
    end
end

function prepare_change_notifier_broadcast(; n_waiters::Int, rounds::Int)
    sim = Simulation()
    notifier = QuantumSavory.ChangeNotifier(sim)

    @process _change_notifier_broadcast_trigger(sim, notifier, rounds)
    for _ in 1:n_waiters
        @process _change_notifier_waiter(sim, notifier, rounds)
    end

    return sim
end

@resumable function _register_broadcast_trigger(sim, reg, rounds)
    for round in 1:rounds
        @yield timeout(sim, 1.0)
        tag!(reg[1], :bench_change_notifier, round)
    end
end

@resumable function _register_waiter(sim, target, rounds)
    for _ in 1:rounds
        @yield onchange(target, Tag)
    end
end

function prepare_register_broadcast(; n_waiters::Int, rounds::Int, wait_on_regref::Bool=false)
    net = RegisterNet([Register(1)])
    sim = get_time_tracker(net)
    reg = net[1]
    target = wait_on_regref ? reg[1] : reg

    @process _register_broadcast_trigger(sim, reg, rounds)
    for _ in 1:n_waiters
        @process _register_waiter(sim, target, rounds)
    end

    return sim
end

SUITE["change_notifier"]["api"] = BenchmarkGroup(["api"])
SUITE["change_notifier"]["api"]["lock_direct"] = @benchmarkable lock(notifier) setup=(sim = Simulation(); notifier = QuantumSavory.ChangeNotifier(sim)) evals=1
SUITE["change_notifier"]["api"]["onchange_register"] = @benchmarkable onchange(reg) setup=(reg = Register(1)) evals=1
SUITE["change_notifier"]["api"]["onchange_regref"] = @benchmarkable onchange(slot, Tag) setup=(reg = Register(1); slot = reg[1]) evals=1

SUITE["change_notifier"]["broadcast_direct"] = BenchmarkGroup(["broadcast_direct"])
for n_waiters in (1, 8, 64, 256)
    label = "waiters_$(n_waiters)_rounds_1"
    SUITE["change_notifier"]["broadcast_direct"][label] = @benchmarkable run(sim) setup=(sim = prepare_change_notifier_broadcast(; n_waiters=$n_waiters, rounds=1)) evals=1
end
for n_waiters in (1, 8, 64)
    label = "waiters_$(n_waiters)_rounds_4"
    SUITE["change_notifier"]["broadcast_direct"][label] = @benchmarkable run(sim) setup=(sim = prepare_change_notifier_broadcast(; n_waiters=$n_waiters, rounds=4)) evals=1
end

SUITE["change_notifier"]["broadcast_register"] = BenchmarkGroup(["broadcast_register"])
for n_waiters in (1, 8, 64, 256)
    label = "waiters_$(n_waiters)_rounds_1"
    SUITE["change_notifier"]["broadcast_register"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_broadcast(; n_waiters=$n_waiters, rounds=1, wait_on_regref=false)) evals=1
end
for n_waiters in (1, 8, 64)
    label = "waiters_$(n_waiters)_rounds_4"
    SUITE["change_notifier"]["broadcast_register"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_broadcast(; n_waiters=$n_waiters, rounds=4, wait_on_regref=false)) evals=1
end

SUITE["change_notifier"]["broadcast_regref"] = BenchmarkGroup(["broadcast_regref"])
for n_waiters in (1, 8, 64, 256)
    label = "waiters_$(n_waiters)_rounds_1"
    SUITE["change_notifier"]["broadcast_regref"][label] = @benchmarkable run(sim) setup=(sim = prepare_register_broadcast(; n_waiters=$n_waiters, rounds=1, wait_on_regref=true)) evals=1
end
