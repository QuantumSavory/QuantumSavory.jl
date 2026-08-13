SUITE["quantumstates"] = BenchmarkGroup(["quantumstates"])
SUITE["quantumstates"]["observable"] = BenchmarkGroup(["observable"])
state = StabilizerState(ghz(5))
proj = projector(state)
express(state)
express(proj)
SUITE["quantumstates"]["observable"]["quantumoptics"] = @benchmarkable observable(reg[1:5], proj) setup=(reg=Register(10); initialize!(reg[1:5], state)) evals=1

SUITE["quantumstates"]["traceout"] = BenchmarkGroup(["traceout"])
SUITE["quantumstates"]["traceout"]["quantummc"] = BenchmarkGroup(["quantummc"])

for n in (10, 12)
    ghz_state = StabilizerState(ghz(n))
    SUITE["quantumstates"]["traceout"]["quantummc"]["partial_ghz_$n"] =
        @benchmarkable traceout!(reg[1]) setup=(
            reg = Register($n, QuantumMCRepr());
            initialize!(reg[1:$n], $ghz_state)
        ) evals=1
    SUITE["quantumstates"]["traceout"]["quantummc"]["complete_ghz_$n"] =
        @benchmarkable traceout!(refs...) setup=(
            reg = Register($n, QuantumMCRepr());
            initialize!(reg[1:$n], $ghz_state);
            refs = reg[1:$n]
        ) evals=1
end

bell_state = StabilizerState("XX ZZ")
function initialize_bell_batch(npairs, state)
    reg = Register(2 * npairs, QuantumMCRepr())
    for i in 1:npairs
        initialize!((reg[i], reg[npairs + i]), state)
    end
    RegRef[reg[i] for i in [1:npairs; (npairs + 1):(2 * npairs)]]
end

for npairs in (16, 64)
    SUITE["quantumstates"]["traceout"]["quantummc"]["complete_bell_pairs_$npairs"] =
        @benchmarkable traceout!(refs...) setup=(
            refs = initialize_bell_batch($npairs, $bell_state)
        ) evals=1
end
