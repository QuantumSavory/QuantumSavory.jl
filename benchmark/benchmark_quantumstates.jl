SUITE["quantumstates"] = BenchmarkGroup(["quantumstates"])
SUITE["quantumstates"]["observable"] = BenchmarkGroup(["observable"])

function prepare_stabilizer_observable_register(n, representation, state)
    reg = Register(n, representation)
    initialize!(reg[1:n], state)
    return reg
end

bell_state = StabilizerState("XX ZZ")
bell_projector = projector(bell_state)
express(bell_state)
express(bell_projector)

SUITE["quantumstates"]["observable"]["bell_projector"] = BenchmarkGroup(["bell_projector"])
SUITE["quantumstates"]["observable"]["bell_projector"]["quantumoptics"] =
    @benchmarkable observable(reg[1:2], bell_projector) setup=(
        reg = prepare_stabilizer_observable_register(2, QuantumOpticsRepr(), bell_state)
    ) evals=1
SUITE["quantumstates"]["observable"]["bell_projector"]["clifford"] =
    @benchmarkable observable(reg[1:2], bell_projector) setup=(
        reg = prepare_stabilizer_observable_register(2, CliffordRepr(), bell_state)
    ) evals=1

SUITE["quantumstates"]["observable"]["ghz_projector"] = BenchmarkGroup(["ghz_projector"])
for n in (3, 5)
    state = StabilizerState(ghz(n))
    proj = projector(state)
    express(state)
    express(proj)

    SUITE["quantumstates"]["observable"]["ghz_projector"]["quantumoptics_$(n)_qubits"] =
        @benchmarkable observable(reg[1:$n], $proj) setup=(
            reg = prepare_stabilizer_observable_register($n, QuantumOpticsRepr(), $state)
        ) evals=1
    SUITE["quantumstates"]["observable"]["ghz_projector"]["clifford_$(n)_qubits"] =
        @benchmarkable observable(reg[1:$n], $proj) setup=(
            reg = prepare_stabilizer_observable_register($n, CliffordRepr(), $state)
        ) evals=1
end
