using ResumableFunctions
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.StatesZoo
using QuantumClifford: ghz
isinteractive() && @eval using Revise

S = 5                 # number of sensors
F = 0.99              # Bell-pair fidelity
success_prob = 0.01   # per-attempt entanglement success probability
attempt_time = 0.001  # duration of a single entanglement attempt
background = Depolarization(1.0)

noisy_pair_func(F) = DepolarizedBellPair(;F)
# Here is how you can do it manually if you want to have a more general state provided by QuantumSymbolics.
# Check out also the StatesZoo as a source of other predefined types of noisy Bell pairs:
# const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
# const perfect_pair_dm = SProjector(perfect_pair)
# const mixed_dm = MixedState(perfect_pair_dm)
# noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm
noisy_pair = noisy_pair_func(F)

# S single-slot sensors plus an S-slot hub at vertex S+1
build_sensor_net(S) =
    RegisterNet([[Register(1, background) for _ in 1:S]; Register(S, background)])

function entangled_sensors(net, S)
    hub_idx = S + 1
    ent = Int[]
    for i in 1:S
        q = query(net[hub_idx], EntanglementCounterpart, i, ❓, ❓; locked=false, assigned=true)
        isnothing(q) || push!(ent, i)
    end
    ent
end

function ghz_project(net, S, ent)
    hub_idx = S + 1

    pair_id(i) = query(net[hub_idx], EntanglementCounterpart, i, ❓, ❓).tag[4]

    # GHZ -> computational basis

    # This "collects" parity information into the first entangled qubit
    for i in ent[2:end]
        apply!([net[hub_idx, ent[1]], net[hub_idx, i]], CNOT)
    end
    apply!(net[hub_idx, ent[1]], H)

    # measure & send correction message
    m1 = project_traceout!(net[hub_idx, ent[1]], Z)
    if m1 == 2
        # If the result is '1' (m1 == 2), the global GHZ state is flipped (X gate needed)
        msg = Tag(EntanglementUpdateX, pair_id(ent[1]), NO_ENTANGLEMENT_ID, hub_idx, ent[1], 1, -1, -1, m1)
        put!(channel(net, hub_idx => ent[1]; permit_forward=true), msg)
    end
    for i in ent[2:end]
        # If m == 2 ('1'), this indicates a relative phase flip (Z gate needed)
        m = project_traceout!(net[hub_idx, i], Z)
        msg = Tag(EntanglementUpdateZ, pair_id(i), NO_ENTANGLEMENT_ID, hub_idx, i, 1, -1, -1, m)
        put!(channel(net, hub_idx => i; permit_forward=true), msg)
    end
end

# GHZ fidelity of the entangled sensors after corrections
function ghz_fidelity(net, ent)
    isempty(ent) && return NaN
    ghz_state = StabilizerState(ghz(length(ent)))
    real(observable([net[i, 1] for i in ent], projector(ghz_state)))
end
