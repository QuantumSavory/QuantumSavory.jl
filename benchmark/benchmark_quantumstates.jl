SUITE["quantumstates"] = BenchmarkGroup(["quantumstates"])
SUITE["quantumstates"]["observable"] = BenchmarkGroup(["observable"])
state = StabilizerState(ghz(5))
proj = projector(state)
express(state)
express(proj)
SUITE["quantumstates"]["observable"]["quantumoptics"] = @benchmarkable observable(reg[1:5], proj) setup=(reg=Register(10); initialize!(reg[1:5], state)) evals=1
SUITE["quantumstates"]["observable"]["clifford"] = @benchmarkable observable(reg[1:5], proj) setup=(reg=Register(10, CliffordRepr()); initialize!(reg[1:5], state)) evals=1

function quantumstates_bell_pair_register(rep)
    reg = Register(2, rep)
    initialize!(reg[1:2], StabilizerState("XX ZZ"))
    return reg
end

function quantumstates_ghz_register(rep)
    reg = Register(5, rep)
    initialize!(reg[1:5], StabilizerState(ghz(5)))
    return reg
end

SUITE["quantumstates"]["project_traceout"] = BenchmarkGroup(["project_traceout"])
SUITE["quantumstates"]["project_traceout"]["quantumoptics_bell_pair"] = @benchmarkable project_traceout!(reg[1], Y) setup=(reg = quantumstates_bell_pair_register(QuantumOpticsRepr())) evals=1
SUITE["quantumstates"]["project_traceout"]["clifford_bell_pair"] = @benchmarkable project_traceout!(reg[1], Y) setup=(reg = quantumstates_bell_pair_register(CliffordRepr())) evals=1
SUITE["quantumstates"]["project_traceout"]["quantumoptics_ghz_5"] = @benchmarkable project_traceout!(reg[3], Y) setup=(reg = quantumstates_ghz_register(QuantumOpticsRepr())) evals=1
SUITE["quantumstates"]["project_traceout"]["clifford_ghz_5"] = @benchmarkable project_traceout!(reg[3], Y) setup=(reg = quantumstates_ghz_register(CliffordRepr())) evals=1
