# Emily's protocol
using ResumableFunctions
using ConcurrentSim
using Revise
using QuantumSavory
using QuantumSavory.ProtocolZoo
const bell = StabilizerState("XX ZZ")
const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm 

S = 5
F = 1 #0.9
fixed_time = 5

noisy_pair = noisy_pair_func(F)

@resumable function GHZ_projection(sim, net, S; time=0.1)
    while true
        queries = []
        incomplete = false

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

        println("all entangled")

        # GHZ -> computational basis
        for i in 2:S
            apply!([net[S + 1, 1], net[S + 1, i]], CNOT)
        end
        apply!(net[S + 1, 1], H)
        
        println("measuring")
        # Measure & correct
        m1 = project_traceout!(net[S + 1, 1], Z)

        println(m1)

        if m1 == 2
            msg1 = Tag(EntanglementUpdateX, S + 1, 1, 1, -1, -1, m1)
            put!(channel(net, S + 1 => 1; permit_forward=true), msg1)
        end

        for i in 2:S
            m = project_traceout!(net[S + 1, i], Z)
            println(i, m)
            msg = Tag(EntanglementUpdateZ, S + 1, i, 1, -1, -1, m)
            put!(channel(net, S + 1 => i; permit_forward=true), msg)
        end

        #for i in 1:S
        #    untag!(queries[i].slot, queries[i].id)
        #end
        #println("deleted all tags")
        @yield timeout(sim, time)
    end
end





net = RegisterNet(vcat([Register(1) for _ in 1:S], [Register(S)]))
sim = get_time_tracker(net)

for i in 1:S
    tracker = EntanglementTracker(sim, net, i)
    @process tracker()
end

for i in 1:S
    eprot = EntanglerProt(sim, net, i, S + 1; pairstate=noisy_pair, chooseA=1, chooseB=i, rounds=1, success_prob=1.)
    @process eprot()
end

@process GHZ_projection(sim, net, S)
run(sim, 10)




ghz5 = StabilizerState("XXXXX ZZIII IZZII IIZZI IIIZZ")

observable([net[1], net[2], net[3], net[4], net[5]], [1, 1, 1, 1, 1], projector(ghz5))



# test correction method


net = RegisterNet(vcat([Register(1) for _ in 1:S], [Register(S)]))
sim = get_time_tracker(net)


for i in 1:S
    eprot = EntanglerProt(sim, net, i, S + 1; pairstate=noisy_pair, chooseA=1, chooseB=i, rounds=1, success_prob=1.)
    @process eprot()
end

run(sim, 10)

for i in 2:S
    apply!([net[S + 1, 1], net[S + 1, i]], CNOT)
end
apply!(net[S + 1, 1], H)


m1 = project_traceout!(net[S + 1, 1], Z)

if m1 == 2
    apply!(net[1, 1], Z)
end
for i in 2:S
    if project_traceout!(net[S + 1, i], Z) == 2
        apply!(net[i, 1], X)                  
    end
end



ghz5 = StabilizerState("XXXXX ZZIII IZZII IIZZI IIIZZ")

observable([net[1], net[2], net[3], net[4], net[5]], [1, 1, 1, 1, 1], projector(ghz5))
