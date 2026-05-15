SUITE["locks"] = BenchmarkGroup(["locks"])

# Lock/unlock basic
SUITE["locks"]["lock_unlock"] = BenchmarkGroup(["lock_unlock"])
SUITE["locks"]["lock_unlock"]["single"] = @benchmarkable begin
    reg = Register(5)
    lock(reg[1])
    unlock(reg[1])
end

# Multi-lock
SUITE["locks"]["lock_unlock"]["multi"] = @benchmarkable begin
    reg = Register(5)
    lock(reg[1])
    lock(reg[3])
    lock(reg[5])
    unlock(reg[1])
    unlock(reg[3])
    unlock(reg[5])
end

# Check islocked
SUITE["locks"]["islocked"] = BenchmarkGroup(["islocked"])
SUITE["locks"]["islocked"]["when_locked"] = @benchmarkable begin
    reg = Register(3)
    lock(reg[2])
    islocked(reg[1])
    islocked(reg[2])
    islocked(reg[3])
    unlock(reg[2])
end
SUITE["locks"]["islocked"]["when_unlocked"] = @benchmarkable begin
    reg = Register(3)
    islocked(reg[1])
    islocked(reg[2])
    islocked(reg[3])
end

# Lock with simulation
@resumable function _lk_worker_a(env, reg)
    lock(reg[1])
    @yield timeout(env, 2.0)
    unlock(reg[1])
end

@resumable function _lk_worker_b(env, reg)
    lock(reg[2])
    @yield timeout(env, 1.0)
    unlock(reg[2])
end

function _run_lock_simulation()
    sim = Simulation()
    reg = Register(3)
    initialize!(reg[1], Z1)
    initialize!(reg[2], Z1)
    @process _lk_worker_a(sim, reg)
    @process _lk_worker_b(sim, reg)
    run(sim)
end

SUITE["locks"]["lock_unlock"]["simulated_concurrent"] = @benchmarkable _run_lock_simulation()
