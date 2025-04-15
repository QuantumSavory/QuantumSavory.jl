using ResumableFunctions
using ConcurrentSim
using Revise

using QuantumSavory
using QuantumSavory.ProtocolZoo
import QuantumSavory: Tag

#using GLMakie
#using GeoMakie
#GLMakie.activate!()

using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm


noisy_pair_func_depol(p) = p*perfect_pair_dm + (1-p)*mixed_dm

function noisy_pair_func(F)
    p = (4*F-1)/3
    return noisy_pair_func_depol(p)
end


F = 0.9

noisy_pair = noisy_pair_func(F)
noisy_pair_99 = noisy_pair_func(0.99)

@kwdef struct ClusterSetUp1
    reg_idx::Int
end
Base.show(io::IO, tag::ClusterSetUp1) = print(io, "Part 1 is completed on $(tag.reg_idx)")
Tag(tag::ClusterSetUp1) = Tag(ClusterSetUp1, tag.reg_idx)


@kwdef struct MBQCMeasurement
    node::Int
    measurement::Int
end
Base.show(io::IO, tag::MBQCMeasurement) = print(io, "Measurement for register $(tag.node) is $(tag.measurement).")
Tag(tag::MBQCMeasurement) = Tag(MBQCMeasurement, tag.node, tag.measurement)

@kwdef struct NuclearEntalgementCounterpart
    remote_node::Int
    remote_slot::Int
end
Base.show(io::IO, tag::NuclearEntalgementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::NuclearEntalgementCounterpart) = Tag(NuclearEntalgementCounterpart, tag.remote_node, tag.remote_slot)

@kwdef struct PurifiedEntalgementCounterpart
    remote_node::Int
    remote_slot::Int
end
Base.show(io::IO, tag::PurifiedEntalgementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::PurifiedEntalgementCounterpart) = Tag(PurifiedEntalgementCounterpart, tag.remote_node, tag.remote_slot)


@resumable function swap(sim, net, idx, tag=EntanglementCounterpart, duration=0.1)
    reg = net[idx]
    while true
        query1 = query(net[idx], tag, ❓, ❓; locked=false, assigned=true) # this is actually specific to EntanglementCounterpart
        if isnothing(query1)
            @yield onchange_tag(reg)
            continue
        else
            print(query1)
            println("Swap at register $(idx) at $(now(sim))")
            @yield lock(reg[1])
            if !isassigned(reg, 2) # nuclear
                initialize!(reg[2])
                apply!(reg[2], H)
            end
            apply!([reg[1], reg[2]], CPHASE)

            m = project_traceout!(reg[1], X)
            if m == 2 # is this allowed within the same register?
                apply!(reg[2], X)
            end
            untag!(query1.slot, query1.id)
            tag!(reg[2], NuclearEntalgementCounterpart, -1, -1) # TODO just a placeholder
            unlock(reg[1])
        end
    end
    # return m
end

@resumable function MBQC_purification_tracker(sim, net, node)
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

@resumable function long_range_entangler(sim, net, rounds; pairstate=noisy_pair, period=0.1)
    round = 1
    while rounds != 0
        # entangle 1 to 5 and 2 to 6, one at a time
        entangler1 = EntanglerProt(sim, net, 1, 5; pairstate=pairstate, chooseA=1, chooseB=1, rounds=1)
        entangler2 = EntanglerProt(sim, net, 2, 6; pairstate=pairstate, chooseA=1, chooseB=1, rounds=1)
        p1 = @process entangler1()
        @yield p1
        query1 = query(net[1], EntanglementCounterpart, 5, 1)
        if !isnothing(query1)
            p2 = @process entangler2()
            @yield p2
        end
        @yield timeout(sim, period)
        @debug "Long range entanglements established"
        rounds==-1 || (rounds -= 1)
        round += 1
    end
end



@resumable function cluster_setup_1(sim, net, reg_idx; pairstate=noisy_pair_99, duration=0.1)
    while true
        query_setup = query(net[(reg_idx - 1)*4 + 4], ClusterSetUp1, reg_idx)
        if !isnothing(query_setup)
            @yield onchange_tag(net[reg_idx])
            continue
        end
        @debug "Part1 starting at reg $(reg_idx)."
        entangler = EntanglerProt(sim, net, (reg_idx - 1)*4 + 3, (reg_idx - 1)*4 + 4; pairstate=pairstate, chooseA=1, chooseB=1, rounds=1)
        p1 = @process entangler()
        @yield p1
        tag!(net[(reg_idx - 1)*4 + 4][2], ClusterSetUp1, reg_idx)
        @yield timeout(sim, duration)
        @debug "Part1 done at reg $(reg_idx)."
    end
end


@resumable function part2(sim, net, reg_idx; pairstate=noisy_pair_99, duration=0.1, period=0.1)
    while true
        query1 = query(net[(reg_idx - 1)*4 + 1], NuclearEntalgementCounterpart, ❓, ❓; locked=false, assigned=true)
        query2 = query(net[(reg_idx - 1)*4 + 2], NuclearEntalgementCounterpart, ❓, ❓; locked=false, assigned=true)
        query3 = query(net[(reg_idx - 1)*4 + 4], ClusterSetUp1, reg_idx)
        if isnothing(query1) || isnothing(query2) || isnothing(query3)
            @yield timeout(sim, period)
            continue
        end
        @debug "Part2 starting at reg $(reg_idx)."
        entangler1 = EntanglerProt(sim, net, (reg_idx - 1)*4 + 1, (reg_idx - 1)*4 + 3; pairstate=pairstate, chooseA=1, chooseB=1, rounds=1)
        entangler2 = EntanglerProt(sim, net, (reg_idx - 1)*4 + 2, (reg_idx - 1)*4 + 3; pairstate=pairstate, chooseA=1, chooseB=1, rounds=1)
        p1 = @process entangler1()
        @yield p1
        p2 = @process entangler2()
        @yield p2

        # do I need to wait?
        m1 = project_traceout!(net[(reg_idx - 1)*4 + 1, 2], X)
        m2 = project_traceout!(net[(reg_idx - 1)*4 + 3, 2], X)

        if m1 == 2
            apply!(net[(reg_idx - 1)*4 + 4, 2], Z)
            apply!(net[(reg_idx - 1)*4 + 2, 2], Z)
        end
        if m2 == 2
            apply!(net[(reg_idx - 1)*4 + 4, 2], X)
        end
        untag!(query1.slot, query1.id)
        untag!(query2.slot, query2.id)
        m = project_traceout!(net[(reg_idx - 1)*4 + 2, 2], X)
        tag!(net[(reg_idx - 1)*4 + 4][2], MBQCMeasurement, reg_idx, m)

        if reg_idx == 1
            other = 2
        else
            other = 1
        end
        @debug "Purification done at node $(node)."
        put!(channel(net, (reg_idx - 1)*4 + 4=>(other - 1)*4 + 4; permit_forward=true), Tag(MBQCMeasurement, reg_idx, m))
        @yield timeout(sim, duration)
    end
end



regsA = [Register(2) for _ in 1:4]
regsB = [Register(2) for _ in 1:4]
net = RegisterNet([regsA; regsB])
sim = get_time_tracker(net)

@process long_range_entangler(sim, net, 1)

@process swap(sim, net, 1)
@process swap(sim, net, 2)
@process swap(sim, net, 3)
@process swap(sim, net, 4)
@process swap(sim, net, 5)
@process swap(sim, net, 6)
@process swap(sim, net, 7)
@process swap(sim, net, 8)

@process MBQC_purification_tracker(sim, net, 4)
@process MBQC_purification_tracker(sim, net, 8)



@process cluster_setup_1(sim, net, 1)
@process cluster_setup_1(sim, net, 2)

@process part2(sim, net, 1)
@process part2(sim, net, 2)

#purified_consumer = EntanglementConsumer(sim, net, 1, 2; period=3, tag=PurifiedEntalgementCounterpart)
#@process purified_consumer()

run(sim, 20)
