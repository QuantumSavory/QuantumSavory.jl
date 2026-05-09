SUITE["quantumstates"] = BenchmarkGroup(["quantumstates"])
SUITE["quantumstates"]["observable"] = BenchmarkGroup(["observable"])
state = StabilizerState(ghz(5))
proj = projector(state)
express(state)
express(proj)
SUITE["quantumstates"]["observable"]["quantumoptics"] = @benchmarkable observable(reg[1:5], proj) setup=(reg=Register(10); initialize!(reg[1:5], state)) evals=1
