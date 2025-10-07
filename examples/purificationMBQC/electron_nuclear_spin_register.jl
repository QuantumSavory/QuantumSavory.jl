using ResumableFunctions
using ConcurrentSim
using Revise
using Graphs
using QuantumSavory
import QuantumSavory: Tag

include("../graphstate/graph_preparer.jl")

using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))


# let's just assume that the overall xor of the measurement results is all we need (maybe wrong) to decide if purification succeeded

@kwdef struct FusionMeasurement
    node::Int
    measurement::Int
end
Base.show(io::IO, tag::FusionMeasurement) = print(io, "Measurement for register $(tag.node) is $(tag.measurement).")
Tag(tag::FusionMeasurement) = Tag(FusionMeasurement, tag.node, tag.measurement)

@kwdef struct MBQCMeasurement
    node::Int
    measurement::Int
end
Base.show(io::IO, tag::MBQCMeasurement) = print(io, "Measurement for register $(tag.node) is $(tag.measurement).")
Tag(tag::MBQCMeasurement) = Tag(MBQCMeasurement, tag.node, tag.measurement)

@kwdef struct XORMeasurements
    node::Int
    xor_result::Int
end
Base.show(io::IO, tag::XORMeasurements) = print(io, "XOR measurement for register $(tag.node) is $(tag.xor_result).")
Tag(tag::XORMeasurements) = Tag(XORMeasurements, tag.node, tag.xor_result)

@kwdef struct PurifiedEntalgementCounterpart
    remote_node::Int
    remote_slot::Int
end
Base.show(io::IO, tag::PurifiedEntalgementCounterpart) = print(io, "Entangled to $(tag.remote_node).$(tag.remote_slot)")
Tag(tag::PurifiedEntalgementCounterpart) = Tag(PurifiedEntalgementCounterpart, tag.remote_node, tag.remote_slot)


# TODO: hardcoded for now
function graph_generator(initial_entanglements_nodes, purified_nodes)
    g = Graph(4)
    for ij in [(1,3), (2,3), (3,4)]
        add_edge!(g, ij...)
    end
    return g
end

# TODO: right now, it just measures all but purified nodes
@resumable function measure(sim, net, side, purified_nodes, storage_slot)
    graph = net.graph
    n = nv(graph)
    offset = side == 1 ? 0 : n÷2
    side_nodes = (1:n÷2) .+ offset
    local_purified_nodes = purified_nodes .+ offset

    xor_result = 0
    for node in side_nodes
        if !(node in local_purified_nodes)
            reg = net[node]
            m = project_traceout!(reg[storage_slot], X) # TODO: fixed basis for now
            tag!(reg[storage_slot], MBQCMeasurement, node, m) # storing the results for now, in case we need to something more sophisticated with them
            xor_result = xor(xor_result, m - 1)
        end
    end

    local_purified = purified_nodes[1] + offset # save XOR result in the first purified node
    reg = net[local_purified]
    tag!(reg[storage_slot], XORMeasurements, local_purified, xor_result)
    remote_purified = purified_nodes[1] + (side == 1 ? n÷2 : 0)
    put!(channel(net, local_purified=>remote_purified), Tag(XORMeasurements, local_purified, xor_result))
    # TODO: send the entangler fusion measurement info as well..
end

@resumable function purification_tracker(sim, net, side, purified_nodes, storage_slot)
    graph = net.graph
    n = nv(graph)
    offset = side == 1 ? 0 : n÷2

    # Local and remote purified nodes
    local_purified = purified_nodes[1] + offset
    remote_purified = purified_nodes[1] + (side == 1 ? n÷2 : 0)

    nodereg = net[local_purified]
    mb = messagebuffer(net, local_purified)

    while true
        # for local XOR measurement result
        local_tag = query(nodereg, XORMeasurements, local_purified, ❓)

        if isnothing(local_tag)
            @yield onchange_tag(net[local_purified])
            continue
        end

        # for remote XOR measurement result
        msg = query(mb, XORMeasurements, remote_purified, ❓)
        if isnothing(msg)
            @debug "Starting message wait at $(now(sim)) with MessageBuffer containing: $(mb.buffer)"
            @yield wait(mb)
            @debug "Done waiting for message at side $(side)"
            continue
        end

        msg = querydelete!(mb, XORMeasurements, ❓, ❓)
        local_xor = local_tag.tag.data[3] # it would be better if it can be local_tag.tag.measurement
        src, (_, src_node, remote_xor) = msg

        if remote_xor == local_xor
            @debug "Purification was successful"
            tag!(local_tag.slot, PurifiedEntalgementCounterpart, src_node, storage_slot)
        else
            @debug "Purification failed."
            untag!(local_tag.slot, local_tag.id)
        end
    end
end



@resumable function entangler_fusion(sim, net, nodeA, nodeB, communication_slot, storage_slot, pairstate)
    regA = net[nodeA]
    regB = net[nodeB]
    @yield lock(regA[storage_slot]) & lock(regA[communication_slot]) & lock(regB[storage_slot]) & lock(regB[communication_slot])
    entangler = EntanglerProt(sim, net, nodeA, nodeB; pairstate=pairstate, chooseA=communication_slot, chooseB=communication_slot, uselock=false, success_prob=1.0, attempts=-1, rounds=1) #TODO: is this realistic?
    p = @process entangler()
    @yield p

    if !isassigned(net[nodeA][storage_slot])
        initialize!(net[nodeA][storage_slot], X1)
    end
    if !isassigned(net[nodeB][storage_slot])
        initialize!(net[nodeB][storage_slot], X1)
    end

    # fusion - long range, so cannot use Fusion in circuitZoo
    apply!((regA[storage_slot], regA[communication_slot]), CPHASE)
    apply!((regB[storage_slot], regB[communication_slot]), CPHASE)

    mA = project_traceout!(regA[communication_slot], X)
    mB = project_traceout!(regB[communication_slot], X)

    # store the info (for correction later)
    tag!(regA[storage_slot], FusionMeasurement, nodeA, mA)
    tag!(regB[storage_slot], FusionMeasurement, nodeB, mB)

    unlock(regA[storage_slot])
    unlock(regA[communication_slot])
    unlock(regB[storage_slot])
    unlock(regB[communication_slot])
end


@resumable function run_protocols(sim, net, graphconstructor1, graphconstructor2, comm_slot, storage_slot, pairstate, initial_entanglements_nodes, purified_nodes; rounds=-1)
    round = 0
    while rounds == -1 || round < rounds
        round += 1
        n = nv(net.graph)
        entanglers = []
        for node in initial_entanglements_nodes
            e = @process entangler_fusion(sim, net, node, node + n÷2, comm_slot, storage_slot, pairstate)
            push!(entanglers, e)
        end

        g1 = @process graphconstructor1()
        g2 = @process graphconstructor2()

        @yield reduce(&, (entanglers..., g1, g2))

        m1 = @process measure(sim, net, 1, purified_nodes, storage_slot)
        m2 = @process measure(sim, net, 2, purified_nodes, storage_slot)
        @yield (m1 & m2)
    end
end




pairstate = StabilizerState("ZX XZ")

initial_entanglements_nodes = [1, 2]
purified_nodes = [4]

graph_state_resource = graph_generator(initial_entanglements_nodes, purified_nodes)

#TODO: the following process can be a function
n = 2*nv(graph_state_resource)
g = Graph(n)

alice_indices = collect(1:n÷2)
bob_indices = alice_indices .+ n÷2

#Alice
for e in edges(graph_state_resource)
    add_edge!(g, src(e), dst(e))
end

# Bob
for e in edges(graph_state_resource)
    add_edge!(g, src(e) + n÷2, dst(e) + n÷2)
end

# long-range edges for initial entanglements and (first) purifed node for communication purposes)
for node in [initial_entanglements_nodes; purified_nodes[1]]
    add_edge!(g, node, node + n÷2)
end

communication_slot = 1
storage_slot = 2
registers = [Register(2) for _ in vertices(g)]

net = RegisterNet(g, registers)
sim = get_time_tracker(net)

alice_subgraph = induced_subgraph(g, alice_indices)[1]
bob_subgraph = induced_subgraph(g, bob_indices)[1]

prepA = GraphStateConstructor(sim, net, alice_subgraph, alice_indices, communication_slot, storage_slot)
prepB = GraphStateConstructor(sim, net, bob_subgraph, bob_indices, communication_slot, storage_slot)

@process run_protocols(sim, net, prepA, prepB, communication_slot, storage_slot, pairstate, initial_entanglements_nodes, purified_nodes)


run(sim, 100)