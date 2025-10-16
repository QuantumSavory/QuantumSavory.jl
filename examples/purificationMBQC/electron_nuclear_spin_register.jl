using ResumableFunctions
using ConcurrentSim
using Revise
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
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


# TODO
function purification_resource_graph(code)
end

# TODO: right now, it just measures all but purified nodes
function measure(sim, net, local_storage_nodes_idx, remote_chief_node_idx, storage_slot)
    xor_result = 0
    for node in local_storage_nodes_idx
        if !(node in local_purified_nodes)
            reg = net[node]
            m = project_traceout!(reg[storage_slot], X) # TODO: fixed basis for now
            xor_result = xor(xor_result, m - 1)
        end
    end

    # save XOR result locally and send it to the remote side
    local_chief_node_idx = local_storage_nodes_idx[1]
    reg = net[local_chief_node_idx]
    tag!(reg[storage_slot], XORMeasurements, local_chief_node_idx, xor_result)
    put!(channel(net, local_chief_node_idx=>remote_chief_node_idx), Tag(XORMeasurements, local_chief_node_idx, xor_result))
    # TODO: send the entangler fusion measurement info as well..
end

@resumable function purification_tracker(sim, net, cluster_nodes_idx, local_chief_node_idx, remote_chief_nodes_idx, storage_slot)
    nodereg = net[local_chief_node_idx]
    mb = messagebuffer(net, local_chief_node_idx)

    while true
        # for local XOR measurement result
        local_tag = query(nodereg, XORMeasurements, local_chief_node_idx, ❓)

        if isnothing(local_tag)
            @yield onchange_tag(net[local_chief_node_idx])
            continue
        end

        # for remote XOR measurement result
        msg = query(mb, XORMeasurements, remote_chief_nodes_idx, ❓)
        if isnothing(msg)
            @debug "Starting message wait at $(now(sim)) with MessageBuffer containing: $(mb.buffer)"
            @yield wait(mb)
            @debug "Done waiting for message at $(local_chief_nodes_idx)"
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
            for node_idx in cluster_nodes_idx
                traceout!(net[node_idx][storage_slot])
            end
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


@resumable function run_protocols(sim, net, n, k, alice_indices, bob_indices, communication_slot, storage_slot, pairstate, initial_entanglements_nodes, purified_nodes; rounds=-1)
    alice_subgraph, vmap = induced_subgraph(net.graph, alice_indices[k+1:k+n+1])
    bob_subgraph, vmap = induced_subgraph(net.graph, bob_indices[k+1:k+n+1])
    prepA = GraphStateConstructor(sim, net, alice_subgraph, alice_indices[k+1:k+n+1], communication_slot, storage_slot)
    prepB = GraphStateConstructor(sim, net, bob_subgraph, bob_indices[k+1:k+n+1], communication_slot, storage_slot)

    round = 0
    while rounds == -1 || round < rounds
        round += 1
        n = nv(net.graph)
        entanglers = []
        for i in 1:k
            e = @process entangler_fusion(sim, net, alice_indices[i], bob_nodes[i], communication_slot, storage_slot, pairstate)
            push!(entanglers, e)
        end
        g1 = @process prepA()
        g2 = @process prepB()

        @yield reduce(&, (entanglers..., g1, g2))
        m1 = @process measure(sim, net, alice_indices[k+1:k+n+1], bob_indices[k+1], storage_slot)
        m2 = @process measure(sim, net, bob_indices[k+1:k+n+1], alice_indices[k+1], storage_slot)
        @yield (m1 & m2)
    end
end



n = 2
k = 1
pairstate = StabilizerState("ZX XZ")


communication_slot = 1
storage_slot = 2

n = 2*nv(graph_state_resource)
registers = [Register(2) for _ in vertices(g)]

net = RegisterNet(g, registers)
sim = get_time_tracker(net)

net.graph
graph_state_resource = graph_generator(initial_entanglements_nodes, purified_nodes)

#TODO: the following process can be a function
n = 2*nv(graph_state_resource)


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

for node in purified_nodes
    purified_consumer = EntanglementConsumer(sim, net, node, node + n÷2; tag=PurifiedEntalgementCounterpart)
    @process purified_consumer()
end


run(sim, 50)