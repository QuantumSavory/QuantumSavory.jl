using BenchmarkTools
using QuantumSavory

SUITE["locks"] = BenchmarkGroup(["locks"])

function register_lock_unlock()
    reg = Register(10)
    lock(reg)
    unlock(reg)
end

function subsystem_lock_unlock()
    reg = Register(10)
    lock(reg[1])
    unlock(reg[1])
end

function register_islocked()
    reg = Register(10)
    islocked(reg)
end

function subsystem_islocked()
    reg = Register(10)
    islocked(reg[1])
end

SUITE["locks"]["register_lock_unlock"] = @benchmarkable register_lock_unlock()
SUITE["locks"]["subsystem_lock_unlock"] = @benchmarkable subsystem_lock_unlock()
SUITE["locks"]["register_islocked"] = @benchmarkable register_islocked()
SUITE["locks"]["subsystem_islocked"] = @benchmarkable subsystem_islocked()
