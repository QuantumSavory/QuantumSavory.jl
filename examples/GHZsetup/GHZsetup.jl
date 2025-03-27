using ResumableFunctions
using ConcurrentSim
using Revise
using QuantumSavory
using QuantumSavory.ProtocolZoo
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

noisy_pair = noisy_pair_func(F)

@resumable function GHZ_projection(sim, net, S; time=0.1)
    while true
        queries = []
        incomplete = false
        # check & wait for all entanglements
        for i in 1:S
            q = query(net[i], EntanglementCounterpart, S + 1, ❓; locked=false, assigned=true)
            if isnothing(q)
                @yield timeout(sim, 0.1)
                incomplete = true
                break
            end
            push!(queries, q)
        end
        if incomplete
            continue
        end

        @debug "All entanglements are ready, at $(now(sim))"

        # GHZ -> computational basis
        for i in 2:S
            apply!([net[S + 1, 1], net[S + 1, i]], CNOT)
        end
        apply!(net[S + 1, 1], H)

        # measure & send correction message
        m1 = project_traceout!(net[S + 1, 1], Z)

        if m1 == 2
            msg1 = Tag(EntanglementUpdateX, S + 1, 1, 1, -1, -1, m1)
            put!(channel(net, S + 1 => 1; permit_forward=true), msg1)
        end

        for i in 2:S
            m = project_traceout!(net[S + 1, i], Z)
            msg = Tag(EntanglementUpdateZ, S + 1, i, 1, -1, -1, m)
            put!(channel(net, S + 1 => i; permit_forward=true), msg)
        end

        @yield timeout(sim, time)
    end
end


# run the simulation


net = RegisterNet(vcat([Register(1) for _ in 1:S], [Register(S)]))
sim = get_time_tracker(net)

for i in 1:S
    # for entanglements and incoming correction messages
    tracker = EntanglementTracker(sim, net, i)
    @process tracker()
end

for i in 1:S
    # entangle sensors with the hub
    eprot = EntanglerProt(sim, net, i, S + 1; pairstate=noisy_pair, chooseA=1, chooseB=i, rounds=1, success_prob=1.)
    @process eprot()
end

@process GHZ_projection(sim, net, S)
run(sim, 10)

ghz5 = StabilizerState("XXXXX ZZIII IZZII IIZZI IIIZZ")

# a bit noisy, but should be close to 1
observable([net[1], net[2], net[3], net[4], net[5]], [1, 1, 1, 1, 1], projector(ghz5))
