using ResumableFunctions
using ConcurrentSim
using Revise
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumClifford: ghz

using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))

const bell = StabilizerState("XX ZZ")
const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)

noisy_pair_func_depol(p) = p*perfect_pair_dm + (1-p)*mixed_dm

function noisy_pair_func(F)
    p = (4*F-1)/3
    return noisy_pair_func_depol(p)
end

S = 5 # number of sensors
F = 0.99 # fidelity
entanglemnt_success_prob = 0.001
fixed_time = 0.5 # time for EntanglerProts

noisy_pair = noisy_pair_func(F)

mutable struct EntangledNodes
    nodes::Vector{Int}
end 

@resumable function GHZ_projection(sim, net, S, fixed_time, entangled; rounds=1, time=0.1)
    hub_idx = S + 1
    while rounds != 0
        println(entangled.nodes)
        @yield timeout(sim, fixed_time + 0.1)  # TODO: Fix this for multiple rounds (probably tag-based)
        entangled_ = Int[]
        for i in 1:S
            q = query(net[hub_idx], EntanglementCounterpart, i, ❓; locked=false, assigned=true)
            if !isnothing(q)
                push!(entangled_, q.tag.data[2])
            end
        end
        entangled.nodes = entangled_
        println(entangled.nodes)
        if length(entangled.nodes) == 0 # no entanglements
            @debug "All entanglement failed"
            break
        else
            @debug "$(length(entangled)) entanglements are ready, at $(now(sim))"
            
            # GHZ -> computational basis
            
            # This "collects" parity information into the first entangled qubit
            for i in entangled.nodes[2:end]
                apply!([net[hub_idx, entangled.nodes[1]], net[hub_idx, i]], CNOT)
            end
            apply!(net[hub_idx, entangled.nodes[1]], H)

            # measure & send correction message
            m1 = project_traceout!(net[hub_idx, entangled.nodes[1]], Z)

            # If the result is '1' (m1 == 2), the global GHZ state is flipped (X gate needed)
            if m1 == 2
                msg1 = Tag(EntanglementUpdateX, hub_idx, entangled.nodes[1], 1, -1, -1, m1)
                put!(channel(net, hub_idx => entangled.nodes[1]; permit_forward=true), msg1)
            end

            # If m == 2 ('1'), this indicates a relative phase flip (Z gate needed)
            for i in entangled.nodes[2:end]
                m = project_traceout!(net[hub_idx, i], Z)
                msg = Tag(EntanglementUpdateZ, hub_idx, i, 1, -1, -1, m)
                put!(channel(net, hub_idx => i; permit_forward=true), msg)
            end

            @yield timeout(sim, time)
        end
        rounds==-1 || (rounds -= 1)
    end
end

@resumable function entangler(sim, net, S, fixed_time, entanglemnt_success_prob)
    procs = []
    for i in 1:S
        # entangle sensors with the hub (S+1)
        eprot = EntanglerProt(sim, net, i, S + 1; pairstate=noisy_pair, chooseA=1, chooseB=i, success_prob=entanglemnt_success_prob)
        @process eprot()
    end
    @yield timeout(sim, fixed_time)
    for p in procs
        cancel!(p)
    end
end

# run the simulation

net = RegisterNet([[Register(1, Depolarization(1.0)) for _ in 1:S]; Register(S, Depolarization(1.0))])

sim = get_time_tracker(net)

entangled_nodes = EntangledNodes(Int[])

for i in 1:S
    # for entanglements and incoming correction messages
    tracker = EntanglementTracker(sim, net, i)
    @process tracker()
end

@process entangler(sim, net, S, fixed_time,entanglemnt_success_prob)

@process GHZ_projection(sim, net, S, fixed_time, entangled_nodes)
run(sim, 1)

ghz_state = StabilizerState(ghz(length(entangled_nodes.nodes)))

# a bit noisy, but should be close to 1
observable([net[i,1] for i in entangled_nodes.nodes], projector(ghz_state))