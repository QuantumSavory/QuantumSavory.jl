include("setup.jl")

using LinearAlgebra: tr
using Statistics: mean
using QuantumSavory.StatesZoo: BarrettKokBellPairW
using QuantumSavory.StatesZoo.Genqo: GenqoMultiplexedCascadedBellPairW

const default_slider_parameters = (
    local_transmission_a=0.9, local_transmission_b=0.9,
    local_detection=0.9, local_dark_counts=0.0001, local_visibility=0.98,
    long_bsm=0.9, long_detection=0.9, long_transmission=0.8, mean_photons=0.05,
    spin_capture_noise=0.0,
)
const default_source_parameters = (; default_slider_parameters..., hadamard_first=false)

const bell_states = StabilizerState.(["ZZ XX", "ZZ -XX", "-ZZ XX", "-ZZ -XX"])
const graph_edge_states = StabilizerState.(["XZ ZX", "-XZ ZX", "XZ -ZX", "-XZ -ZX"])

# For real visibility, both source models are Bell diagonal after their known
# local Pauli corrections. Reconstruct the density matrix to check this instead
# of silently twirling away coherences. CliffordRepr samples a fresh component
# of the symbolic mixture at EVERY initialize!, including every local graph edge.
function source_mixture(weighted_state, correction;
        graph_edge=false, hadamard_first=false, depolarization=0.0)
    0 <= depolarization <= 1 || throw(ArgumentError("depolarization must be between zero and one"))
    weighted = express(weighted_state, QuantumOpticsRepr())
    probability = real(tr(weighted))
    0 < probability <= 1 || error("The source must have a nonzero heralding probability.")
    unitary = express(correction, QuantumOpticsRepr())
    density = unitary * weighted * unitary' / probability
    projectors = [express(SProjector(s), QuantumOpticsRepr()) for s in bell_states]
    weights = [real(tr(p * density)) for p in projectors]
    @assert all(>=(-1e-12), weights)
    weights = max.(0.0, weights)
    weights ./= sum(weights)
    @assert isapprox(sum(weights .* projectors).data, density.data; atol=1e-10)
    # After heralding, uniformly randomize over all 16 two-qubit Paulis with
    # probability p: ρ → (1-p)ρ + p I₄/4. This preserves the heralding probability.
    weights = (1 - depolarization) .* weights .+ depolarization / 4
    states = graph_edge ? graph_edge_states : bell_states
    # H on either endpoint gives the same ideal graph edge. H on the first
    # endpoint exchanges where the phase and bit errors enter the graph.
    if graph_edge && hadamard_first
        states = states[[1, 3, 2, 4]]
    end
    mixture = sum(w * SProjector(s) for (w, s) in zip(weights, states) if w > 0)
    (; state=mixture, probability, fidelity=weights[1])
end

function purification_sources(parameters)
    p = parameters
    local_model = BarrettKokBellPairW(p.local_transmission_a, p.local_transmission_b,
        p.local_dark_counts, p.local_detection, p.local_visibility)
    long_model = GenqoMultiplexedCascadedBellPairW(p.long_bsm, p.long_detection,
        p.long_transmission, p.mean_photons)
    # BK's m=0 convention is Ψ+; Genqo's fixed click pattern gives Φ−.
    # After conversion to Φ+, H on the selected local qubit makes a graph edge.
    local_source = source_mixture(local_model, I⊗X;
        graph_edge=true, hadamard_first=p.hadamard_first)
    long_source = source_mixture(long_model, I⊗Z; depolarization=p.spin_capture_noise)
    (; local_source, long_source)
end

function purification_trial(parameters, sources=purification_sources(parameters))
    (; local_source, long_source) = sources
    net = RegisterNet([Register(2, CliffordRepr()) for _ in 1:2*(n+k)])
    sim = get_time_tracker(net)
    @process run_purification(sim, net, n, resource_state, alice_nodes, bob_nodes,
        communication_slot, storage_slot, long_source.state, H1, H2, logxs, logzs,
        local_pairstate=local_source.state, local_success_prob=local_source.probability,
        local_attempt_time=1.0, success_prob=long_source.probability, attempt_time=1.0)
    # Drain scheduled events, including both trackers' corrections. A fixed
    # simulation deadline would bias against the slower slider configurations.
    try
        while true
            ConcurrentSim.step(sim)
        end
    catch error
        error isa ConcurrentSim.EmptySchedule || rethrow()
    end
    accepted = all(!isnothing(query(net[node][storage_slot],
        PurifiedEntanglementCounterpart, ❓, ❓)) for node in
        vcat(alice_nodes[n+1:end], bob_nodes[n+1:end]))
    fidelity = accepted ? mean(real(observable(
        (net[alice_nodes[n+i]][storage_slot], net[bob_nodes[n+i]][storage_slot]),
        SProjector(bell_states[1]))) for i in 1:k) : NaN
    (; parameters, duration=now(sim), accepted, fidelity,
        input_fidelity=long_source.fidelity, local_fidelity=local_source.fidelity,
        local_probability=local_source.probability, long_probability=long_source.probability)
end

function retain_trial!(history, result)
    push!(history, result)
    length(history) > 100 && popfirst!(history)
    history
end
