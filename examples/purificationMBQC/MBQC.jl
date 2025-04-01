using ResumableFunctions
using ConcurrentSim
using Revise

using QuantumSavory
using QuantumSavory.ProtocolZoo
import QuantumSavory: Tag

using GLMakie
using GeoMakie
GLMakie.activate!()

using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm 

F = 0.9

noisy_pair = noisy_pair_func(F)

@kwdef struct MBQCSetUp
    node::Int
end
Base.show(io::IO, tag::MBQCSetUp) = print(io, "Set up is completed on $(tag.node)")
Tag(tag::MBQCSetUp) = Tag(MBQCSetUp, tag.node)


@kwdef struct MBQCMeasurement
    node::Int
    measurement::Int
end
Base.show(io::IO, tag::MBQCMeasurement) = print(io, "Measurement for register $(tag.node) is $(tag.measurement).")
Tag(tag::MBQCMeasurement) = Tag(MBQCMeasurement, tag.node, tag.measurement)

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
        local_tag = query(nodereg, MBQCMeasurement, node, ❓)

        if isnothing(local_tag)
            @yield onchange_tag(net[node])
            continue
        end
        
        msg = query(mb, MBQCMeasurement, ❓, ❓)
        if isnothing(msg)
            @debug "Starting message wait at $(now(sim)) with MessageBuffer containing: $(mb.buffer)"
            @yield wait(mb)
            @debug "Done waiting for message at $(node)"
            continue
        end

        msg = querydelete!(mb, MBQCMeasurement, ❓, ❓)
        local_measurement = local_tag.tag.data[3] # it would be better if it can be local_tag.tag.measurement 
        src, (_, src_node, src_measurement) = msg

        if src_measurement == local_measurement
            @debug "Purification was successful"
            tag!(local_tag.slot, PurifiedEntalgementCounterpart, src_node, 4)

        else
            @debug "Purification failed."
            untag!(local_tag.slot, local_tag.id)
        end
    end
end

@resumable function MBQC_setup(sim, net, node, duration=0.1, period=0.1)
    while true
        query_setup = query(net[node], MBQCSetUp, node)
        if !isnothing(query_setup)
            if isnothing(period)
                @yield onchange_tag(net[node])
            else
                @yield timeout(sim, period)
            end
            continue
        end
        @debug "Setup starting at node $(node)."
        initialize!(net[node, 3], X1)
        initialize!(net[node, 4], X1)
        apply!((net[node, 3], net[node, 4]), CPHASE)
        @yield timeout(sim, duration)
        tag!(net[node][4], MBQCSetUp, node)
        @debug "Setup done at node $(node)."
    end
end
@resumable function entangler(sim, net; pairstate=noisy_pair, period=0.1)
    while true
        # entangle 1 to 1 and 2 to 2
        entangler1 = EntanglerProt(sim, net, 1, 2; pairstate=pairstate, chooseA=1, chooseB=1, rounds=1)
        entangler2 = EntanglerProt(sim, net, 1, 2; pairstate=pairstate, chooseA=2, chooseB=2, rounds=1)
        @process entangler1()
        query1 = query(net[1], EntanglementCounterpart, 2, 1)
        if !isnothing(query1)
            @process entangler2()
        end
        @yield timeout(sim, period)
    end
end

@resumable function MBQC_purify(sim, net, node, duration=0.1, period=0.1)
    while true
        query1 = queryall(net[node], EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
        query2 = query(net[node], MBQCSetUp, node)
        if length(query1) < 2 || isnothing(query2)
            if isnothing(period)
                @yield onchange_tag(net[node])
            else
                @yield timeout(sim, period)
            end
            continue
        end
        println(query1)
        @debug "Purification starting at node $(node)."

        apply!((net[node, 3], net[node, 1]), CPHASE)
        apply!((net[node, 3], net[node, 2]), CPHASE)

        m1 = project_traceout!(net[node, 1], X)
        m2 = project_traceout!(net[node, 3], X)

        if m1 == 2
            apply!(net[node, 4], Z)
            apply!(net[node, 2], Z)
        end 
        if m2 == 2
            apply!(net[node, 4], X)
        end
        untag!(query1[1].slot, query1[1].id)
        untag!(query1[2].slot, query1[2].id)
        m = project_traceout!(net[node, 2], X) 
        tag!(net[node][4], MBQCMeasurement, node, m)
        
        if node == 1
            other = 2
        else
            other = 1
        end
        @debug "Purification done at node $(node)."
        put!(channel(net, node=>other), Tag(MBQCMeasurement, node, m))
        @yield timeout(sim, duration)
    end
end




regL = Register(4)
regR = Register(4)
net = RegisterNet([regL, regR])
sim = get_time_tracker(net)

@process entangler(sim, net)
@process MBQC_tracker(sim, net, 1)
@process MBQC_tracker(sim, net, 2)



@process MBQC_setup(sim, net, 1)
@process MBQC_setup(sim, net, 2)

@process MBQC_purify(sim, net, 1)
@process MBQC_purify(sim, net, 2)

purified_consumer = EntanglementConsumer(sim, net, 1, 2; period=3, tag=PurifiedEntalgementCounterpart)
@process purified_consumer()

run(sim, 2)

observable([net[1], net[2]], [1, 1], projector(perfect_pair))
observable([net[1], net[2]], [2, 2], projector(perfect_pair))

# has not been consumed yet
observable([net[1], net[2]], [4, 4], projector(perfect_pair))


run(sim, 4)

# should be consumed and return nothing
observable([net[1], net[2]], [4, 4], projector(perfect_pair))

