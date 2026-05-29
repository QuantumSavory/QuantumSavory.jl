using QuantumSavory: NonInstantGate

SUITE["operations"] = BenchmarkGroup(["operations"])
SUITE["operations"]["apply"] = BenchmarkGroup(["apply"])
SUITE["operations"]["observable"] = BenchmarkGroup(["observable"])
SUITE["operations"]["measurement"] = BenchmarkGroup(["measurement"])
SUITE["operations"]["noninstant"] = BenchmarkGroup(["noninstant"])

function benchmark_bell_stabilizer()
    return StabilizerState("XX ZZ")
end

function prepare_quantumoptics_single_qubit()
    reg = Register([Qubit()], [QuantumOpticsRepr()])
    initialize!(reg[1], Z1)
    return reg
end

function prepare_clifford_single_qubit()
    reg = Register([Qubit()], [CliffordRepr()])
    initialize!(reg[1], Z1)
    return reg
end

function prepare_quantumoptics_pair()
    reg = Register([Qubit(), Qubit()], [QuantumOpticsRepr(), QuantumOpticsRepr()])
    initialize!(reg[1], Z1)
    initialize!(reg[2], X1)
    return reg
end

function prepare_clifford_pair()
    reg = Register([Qubit(), Qubit()], [CliffordRepr(), CliffordRepr()])
    initialize!(reg[1], Z1)
    initialize!(reg[2], X1)
    return reg
end

function prepare_quantumoptics_bell_pair()
    reg = Register([Qubit(), Qubit()], [QuantumOpticsRepr(), QuantumOpticsRepr()])
    initialize!(reg[1:2], benchmark_bell_stabilizer())
    return reg
end

function prepare_clifford_bell_pair()
    reg = Register([Qubit(), Qubit()], [CliffordRepr(), CliffordRepr()])
    initialize!(reg[1:2], benchmark_bell_stabilizer())
    return reg
end

function prepare_noninstant_pair()
    reg = Register([Qubit(), Qubit()])
    initialize!(reg[1])
    initialize!(reg[2])
    return reg
end

# Basic operation benchmarks across the dense-state and Clifford backends.
SUITE["operations"]["apply"]["single_h_quantumoptics"] = @benchmarkable apply!(reg[1], H) setup=(reg = prepare_quantumoptics_single_qubit()) evals=1
SUITE["operations"]["apply"]["single_h_clifford"] = @benchmarkable apply!(reg[1], H) setup=(reg = prepare_clifford_single_qubit()) evals=1
SUITE["operations"]["apply"]["cnot_quantumoptics"] = @benchmarkable apply!(reg[1:2], CNOT) setup=(reg = prepare_quantumoptics_pair()) evals=1
SUITE["operations"]["apply"]["cnot_clifford"] = @benchmarkable apply!(reg[1:2], CNOT) setup=(reg = prepare_clifford_pair()) evals=1

SUITE["operations"]["observable"]["bell_projector_quantumoptics"] = @benchmarkable observable(reg[1:2], obs) setup=(reg = prepare_quantumoptics_bell_pair(); obs = SProjector(benchmark_bell_stabilizer())) evals=1
SUITE["operations"]["observable"]["bell_projector_clifford"] = @benchmarkable observable(reg[1:2], obs) setup=(reg = prepare_clifford_bell_pair(); obs = SProjector(benchmark_bell_stabilizer())) evals=1
SUITE["operations"]["observable"]["single_z_quantumoptics"] = @benchmarkable observable(reg[1], Z) setup=(reg = prepare_quantumoptics_single_qubit()) evals=1
SUITE["operations"]["observable"]["single_z_clifford"] = @benchmarkable observable(reg[1], Z) setup=(reg = prepare_clifford_single_qubit()) evals=1

SUITE["operations"]["measurement"]["traceout_x_quantumoptics"] = @benchmarkable project_traceout!(reg[1], X) setup=(reg = prepare_quantumoptics_bell_pair()) evals=1
SUITE["operations"]["measurement"]["traceout_x_clifford"] = @benchmarkable project_traceout!(reg[1], X) setup=(reg = prepare_clifford_bell_pair()) evals=1

SUITE["operations"]["noninstant"]["single_h"] = @benchmarkable apply!(reg[1], NonInstantGate(H, 0.1); time=0.4) setup=(reg = prepare_noninstant_pair(); apply!(reg[1], H; time=0.3)) evals=1
SUITE["operations"]["noninstant"]["cnot"] = @benchmarkable apply!([reg[1], reg[2]], NonInstantGate(CNOT, 0.1)) setup=(reg = prepare_noninstant_pair()) evals=1
