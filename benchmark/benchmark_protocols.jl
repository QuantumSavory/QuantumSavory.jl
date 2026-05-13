SUITE["protocols"] = BenchmarkGroup(["protocols"])

# Protocol-level smoke benchmarks exercise full simulation paths rather than only
# individual data-structure calls. They are intentionally small and deterministic
# so they can run in CI while still covering realistic Entangler/Tracker/Swapper
# interactions used by the examples.
function protocol_entangler_pair(; rounds::Int=4)
    net = RegisterNet([Register(2), Register(2)])
    sim = get_time_tracker(net)

    @process EntanglerProt(sim, net, 1, 2; chooseslotA=1, chooseslotB=1, rounds=rounds, success_prob=1.0)()
    run(sim, 10 * rounds)

    @assert observable([net[1], net[2]], [1, 1], projector((Z1⊗Z1 + Z2⊗Z2) / sqrt(2))) ≈ 1.0
    return net
end

function protocol_tracker_chain(; rounds::Int=2)
    net = RegisterNet([Register(2), Register(2), Register(2)])
    sim = get_time_tracker(net)

    @process EntanglerProt(sim, net, 1, 2; chooseslotA=1, chooseslotB=1, rounds=rounds, success_prob=1.0)()
    @process EntanglerProt(sim, net, 2, 3; chooseslotA=2, chooseslotB=1, rounds=rounds, success_prob=1.0)()
    for node in 1:3
        @process EntanglementTracker(sim, net, node)()
    end
    run(sim, 20 * rounds)

    @assert query(net[1], EntanglementCounterpart, 2, ❓) !== nothing
    @assert query(net[2], EntanglementCounterpart, 1, ❓) !== nothing
    @assert query(net[2], EntanglementCounterpart, 3, ❓) !== nothing
    @assert query(net[3], EntanglementCounterpart, 2, ❓) !== nothing
    return net
end

function protocol_swapper_chain(; rounds::Int=1)
    net = RegisterNet([Register(4), Register(4), Register(4)])
    sim = get_time_tracker(net)

    @process EntanglerProt(sim, net, 1, 2; chooseslotA=1, chooseslotB=1, rounds=rounds, success_prob=1.0)()
    @process EntanglerProt(sim, net, 2, 3; chooseslotA=2, chooseslotB=1, rounds=rounds, success_prob=1.0)()
    for node in 1:3
        @process EntanglementTracker(sim, net, node)()
    end
    @process SwapperProt(sim, net, 2; chooseslots=[1, 2], nodeL = ==(1), nodeH = ==(3), rounds=rounds)()
    run(sim, 200 * rounds)

    left = query(net[1], EntanglementCounterpart, 3, ❓)
    right = query(net[3], EntanglementCounterpart, 1, ❓)
    @assert left !== nothing
    @assert right !== nothing
    @assert observable((left.slot, right.slot), Z⊗Z) ≈ 1
    @assert observable((left.slot, right.slot), X⊗X) ≈ 1
    return net
end

SUITE["protocols"]["entangler"] = BenchmarkGroup(["entangler"])
SUITE["protocols"]["entangler"]["pair_rounds_1"] = @benchmarkable protocol_entangler_pair(; rounds=1) evals=1
SUITE["protocols"]["entangler"]["pair_rounds_4"] = @benchmarkable protocol_entangler_pair(; rounds=4) evals=1

SUITE["protocols"]["tracker"] = BenchmarkGroup(["tracker"])
SUITE["protocols"]["tracker"]["three_node_chain_rounds_1"] = @benchmarkable protocol_tracker_chain(; rounds=1) evals=1
SUITE["protocols"]["tracker"]["three_node_chain_rounds_2"] = @benchmarkable protocol_tracker_chain(; rounds=2) evals=1

SUITE["protocols"]["swapper"] = BenchmarkGroup(["swapper"])
SUITE["protocols"]["swapper"]["three_node_chain_rounds_1"] = @benchmarkable protocol_swapper_chain(; rounds=1) evals=1
