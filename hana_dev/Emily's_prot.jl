# Emily's protocol
using Graphs

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
F = 0.9
fixed_time = 5

noisy_pair = noisy_pair_func(F)
net = RegisterNet(vcat([Register(1) for _ in 1:S], [Register(S)]))
sim = get_time_tracker(net)

for i in 1:S
    eprot = EntanglerProt(sim, net, i, S + 1; pairstate=noisy_pair, chooseA=1, chooseB=i, rounds=1, success_prob=1.)
    @process eprot()
end

@resumable function GHZ_projection(sim, net, time=0.1)
    while true
        for i in 1:S # for the fixed-time version, it is not necessarily true that all of them are entangled.
            query = query(net[i], EntanglementCounterpart, S + 1, ❓; locked=false, assigned=true)
            if isnothing(query)
                @yield timeout(sim, 0.1)
                continue
            end
        end
        for i in 2:S
            apply!([net[S + 1, 1], net[S + 1, i]], CNOT)
        end
        apply!(net[S + 1, 1], H)
        for i in 1:S
            project_traceout!(net[S + 1, i], Z)
        end
        @yield timeout(sim, time)
    end
end

@process GHZ_projection(sim, net)


run(sim, 10)

# how to check the result?






observable([net[1], net[6]], [1, 1], projector(bell))

observable([net[2], net[6]], [1, 2], projector(bell))

observable([net[3], net[6]], [1, 3], projector(bell))


apply!([net[6, 1], net[6, 2]], CNOT)

project_traceout!(net[S + 1, i], Z)






















eprot = EntanglerProt(sim, net, 1, 2; rounds=1)

    @resumable GHZ_projection(sim, net, time_before=0.1)
    @yield timeout(sim, 1)
    project_traceout!(net[S+1], [1:S], GHZ(S))
end




EntanglerProt(sim, net, 1, 2; rounds=1)




i = 1
eprot = EntanglerProt(sim, net, 1, S + 1; pairstate=noisy_pair, chooseA=1, chooseB=1)
@process eprot

eprot = EntanglerProt(sim, net, 1, )
@process eprot()

run(sim, 10)




reg1 = Register(3)
a = queryall(reg1, 1)

entangler = EntanglerProt(sim, net, i, i+S, round=5, pairstate=noisy_pair)


@resumable purify_prot(sim, net, time=0.1)
query1 = query(purifiedL[1], EntanglementCounterpart, purifiedR[1], ❓; locked=false, assigned=true) # TODO Need a `querydelete!` dispatch on `Register` rather than using `query` here followed by `untag!` below
end

@resumable GHZ_proj_prot(sim, net, time=0.1)
    project_traceout!( bell)
end

# checking which nodes have entangled pair(s)
# purification - more than 3 nodes?
# purify_prot, GHZ_proj_prot - check the 
reg = Register(3)
n_slots = length(reg.staterefs)
freeslots = sum((!isassigned(reg[i]) for i in 1:n_slots))
slots = [i for i in 1:n_slots if !isassigned(reg[i]) || isassigned(slot)]
choose = argmin
if choose isa Int
    return choose in slots ? reg[choose] : nothing
else
    i = choose(slots)
    return reg[i]
end

function findfreeslot_filter(reg::Register; filter=argmin::function, margin=0)
    n_slots = length(reg.staterefs)
    freeslots = sum((!isassigned(reg[i]) for i in 1:n_slots))
    slots = [i for i in 1:n_slots if !isassigned(reg[i]) || isassigned(slot)]
    if freeslots >= margin
        if choose isa Int
            return choose in slots ? reg[choose] : nothing
        else
            i = choose(slots)
            return reg[i]
        end
    end
end



