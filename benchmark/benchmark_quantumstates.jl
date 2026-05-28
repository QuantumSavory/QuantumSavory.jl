SUITE["quantumstates"] = BenchmarkGroup(["quantumstates"])
SUITE["quantumstates"]["observable"] = BenchmarkGroup(["observable"])
state = StabilizerState(ghz(5))
proj = projector(state)
express(state)
express(proj)
SUITE["quantumstates"]["observable"]["quantumoptics"] = @benchmarkable observable(reg[1:5], proj) setup=(reg=Register(10); initialize!(reg[1:5], state)) evals=1

using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoMultiplexedCascadedBellPairW, GenqoUnheraldedSPDCBellPairW

SUITE["quantumstates"]["stateszoo"] = BenchmarkGroup(["stateszoo"])
SUITE["quantumstates"]["stateszoo"]["express"] = BenchmarkGroup(["express"])
SUITE["quantumstates"]["stateszoo"]["initialize"] = BenchmarkGroup(["initialize"])

function good_stateszoo_state(::Type{S}) where {S}
    params = QuantumSavory.StatesZoo.stateparameters(S)
    ranges = QuantumSavory.StatesZoo.stateparametersrange(S)
    return S((ranges[p].good for p in params)...)
end

stateszoo_models = (
    "depolarized_bell_pair" => DepolarizedBellPair,
    "barrett_kok_bell_pair" => BarrettKokBellPair,
    "barrett_kok_bell_pair_weighted" => BarrettKokBellPairW,
    "genqo_unheralded_spdc_bell_pair_weighted" => GenqoUnheraldedSPDCBellPairW,
    "genqo_multiplexed_cascaded_bell_pair_weighted" => GenqoMultiplexedCascadedBellPairW,
)

for (label, state_type) in stateszoo_models
    model_state = good_stateszoo_state(state_type)
    SUITE["quantumstates"]["stateszoo"]["express"][label] = @benchmarkable express($model_state)
    SUITE["quantumstates"]["stateszoo"]["initialize"][label] = @benchmarkable initialize!(reg[1:2], $model_state) setup=(reg = Register(2)) evals=1
end
