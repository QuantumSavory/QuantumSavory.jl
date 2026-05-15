SUITE["examples"] = BenchmarkGroup(["examples"])

# Bell state channel example
@resumable function _ex_send(env, qc, alice)
    put!(qc, alice[1])
end

@resumable function _ex_recv(env, qc, bob)
    @yield take!(qc, bob[1])
end

function _run_bell_channel()
    sim = Simulation()
    alice = Register(1)
    bob = Register(1)
    initialize!(alice[1], (Z1 + X1)/√2)
    qc = QuantumChannel(sim, 5.0)
    @process _ex_send(sim, qc, alice)
    @process _ex_recv(sim, qc, bob)
    run(sim)
    measure!(bob[1], Z1)
end

SUITE["examples"]["bell_channel"] = @benchmarkable _run_bell_channel()

# Teleport example
function _run_teleport()
    sim = Simulation()
    alice = Register(2)
    bob = Register(1)
    initialize!(alice[1], (Z1 + X1)/√2)
    initialize!(alice[2], Z1)
    apply!([alice[2], bob[1]], CNOT)
    apply!(alice[1], H)
    m1 = measure!(alice[1], Z1)
    m2 = measure!(alice[2], Z1)
    if m2 == 1
        apply!(bob[1], X)
    end
    if m1 == 1
        apply!(bob[1], Z)
    end
end

SUITE["examples"]["teleport"] = @benchmarkable _run_teleport()

# Register operations example
function _run_register_ops()
    reg = Register(5)
    for i in 1:5
        initialize!(reg[i], Z1)
    end
    apply!([reg[1], reg[2]], CNOT)
    apply!([reg[3], reg[4]], CNOT)
    apply!(reg[5], H)
    m = measure!(reg[1], Z1)
    tag!(reg[1], :measured, m)
    q = query(reg, :measured, ❓)
end

SUITE["examples"]["register_ops"] = @benchmarkable _run_register_ops()
