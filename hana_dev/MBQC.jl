using ResumableFunctions
using ConcurrentSim
using Revise

using QuantumSavory
using QuantumSavory.ProtocolZoo

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm 

F = 0.9

noisy_pair = noisy_pair_func(F)

@kwdef struct MBQCSetUp
    node::Int
    measurement::Int
end
Base.show(io::IO, tag::MBQCSetUp) = print(io, "Set up is completed on $(tag.node).")
Tag(tag::MBQCSetUp) = Tag(MBQCSetUp, tag.node, tag.measurement)

Tag(MBQCSetUp, 1, 1)

@kwdef struct PurifiedEntalgementCounterpart
    remote_node::Int
    remote_slot::Int
end
Base.show(io::IO, tag::PurifiedEntalgementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::PurifiedEntalgementCounterpart) = Tag(PurifiedEntalgementCounterpart, tag.remote_node, tag.remote_slot)

@resumable function MBQC_tracker(sim, net, node)
    nodereg = net[node]
    mb = messagebuffer(net, node)
    while true
        msg = querydelete!(mb, MBQCSetUp, ❓, ❓)
        isnothing(msg) && continue
        src, (_, src_node, src_measurement) = msg

        local_tag = query(nodereg, MBQCSetUp, node, ❓)
        local_measurement = local_tag.measurement 
        isnothing(local_tag) && continue

        if src_measurement == local_measurement
            @debug  "Purification was successful"
            tag!(local_tag.slot, PurifiedEntalgementCounterpart, src_node, 4)

        else
            @debug "Purification failed"
            untag!(local_tag.slot, local_tag.id)
        end

        @yield timeout(sim, 0.1)
    end

end

@resumable function MBQC_purify(sim, net, node, duration=0.1, period=0.1)

    while true
        query1 = queryall(net[node], EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
        query2 = query(net[node], MBQCSetUp, node)
        if length(query1) < 2 || !isnothing(query2)
            if isnothing(period)
                @yield onchange_tag(net[node])
            else
                @yield timeout(sim, period)
            end
            continue
        end
    
        initialize!(net[node, 3], X1)
        initialize!(net[node, 4], X1)

        apply!((net[node, 3], net[node, 1]), CPHASE)
        apply!((net[node, 3], net[node, 2]), CPHASE)
        apply!((net[node, 3], net[node, 4]), CPHASE)

        m1 = project_traceout!(net[node, 1], X)
        m2 = project_traceout!(net[node, 3], X)
        if m1 == 2
            apply!(net[node, 4], X)
        end
        if m2 == 2
            apply!(net[node, 4], Z)
            apply!(net[node, 2], Z)
        end 

        m = project_traceout!(net[node, 2], X) 
        tag!(net[node][4], MBQCSetUp, node, m)
        if node == 1
            other = 2
        else
            other = 1
        end
        put!(channel(net, node=>other), Tag(MBQCSetUp, node, m))
        println("set up complete", node)
    end
end

put!(channel(net, 1=>2), Tag(MBQCSetUp, 1, 1))


Tag(MBQCSetUp, 1, 1)

mbqc = MBQCSetUp(node=1, measurement=1)
tag_instance = Tag(mbqc)  # This will work

regL = Register(4)
regR = Register(4)
net = RegisterNet([regL, regR])
sim = get_time_tracker(net)

#@process MBQC_tracker(sim, net, 1)
#@process MBQC_tracker(sim, net, 2)

# entangle 1 to 1 and 2 to 2
entangler1 = EntanglerProt(sim, net, 1, 2; pairstate=noisy_pair, chooseA=1, chooseB=1, success_prob=1.0, rounds=1)
entangler2 = EntanglerProt(sim, net, 1, 2, pairstate=noisy_pair, chooseA=2, chooseB=2, success_prob=1.0, rounds=1)
@process entangler1()
@process entangler2()

@process MBQC_purify(sim, net, 1)
@process MBQC_purify(sim, net, 2)

run(sim, 1)

const bell = StabilizerState("XX ZZ")
observable([net[1], net[2]], [1, 1], projector(bell))


query1 = queryall(net[1], EntanglementCounterpart, ❓, ❓; locked=false, assigned=true)

length(query1)

tag!(net[1][1], MBQCSetUp, 1, 2)