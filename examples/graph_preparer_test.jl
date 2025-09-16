using QuantumSavory
using ConcurrentSim
using ResumableFunctions
import HiGHS
using JuMP: JuMP, MOI
using Graphs
using GraphsMatching: maximum_weight_matching

import QuantumSavory.ProtocolZoo: AbstractProtocol, EntanglerProt

import QuantumClifford
import QuantumOpticsBase

##

"""
    graph_builder(g::Graph)

A re-entrant graph-state compilation steps generator.
Returns lists of edges that can be entangled in parallel by using
maximal cardinality matching on the given graph.

Consider this graph where 1-2 and 3-4 can be created in parallel:
```
   4
   |
   3
  / \
 1───2
```

Prepare the compiler by specifying the graph state to be generated:

```jldoctest graphcompile
julia> g = Graph(4); for ij in [(1,2),(2,3),(1,3),(3,4)] add_edge!(g, ij...) end

julia> step_gen = graph_builder(g);
```

Then execute it once in order to get the first round of edges that need to be entangled:

```jldoctest graphcompile
julia> step_gen()
2-element Vector{Tuple{Int64, Int64}}:
 (1, 2)
 (3, 4)

julia> step_gen()
1-element Vector{Tuple{Int64, Int64}}:
 (2, 3)

julia> step_gen()
1-element Vector{Tuple{Int64, Int64}}:
 (1, 3)

julia> step_gen() |> isnothing # the generator returns `nothing` when done
true
```

Importantly, if the link generation is probabilistic and only part of the links succeed,
you can provide that information back to the generator, so that it can account for failed attempts:

```jldoctest
julia> g = Graph(4); for ij in [(1,2),(2,3),(1,3),(3,4)] add_edge!(g, ij...) end

julia> step_gen = graph_builder(g);

julia> step_gen()
2-element Vector{Tuple{Int64, Int64}}:
 (1, 2)
 (3, 4)

julia> step_gen([(3,4)]) # assume only 3-4 was successfully generated
1-element Vector{Tuple{Int64, Int64}}:
 (2, 3)

julia> step_gen()
1-element Vector{Tuple{Int64, Int64}}:
 (1, 2)

julia> step_gen()
1-element Vector{Tuple{Int64, Int64}}:
 (1, 3)

julia> step_gen() |> isnothing # the generator returns `nothing` when done
true
```
"""
@resumable function graph_builder(g) # TODO currently it has the capability to be told "these succeeded"; but we can improve it so that we can additionally say "these are currently being attempted"
    current_graph = copy(g)
    while ne(current_graph)>0
        opt = JuMP.optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent()=>true)
        m = maximum_weight_matching(current_graph, opt)
        match = Tuple{Int,Int}[]
        for i in vertices(current_graph)
            if m.mate[i]!=-1 && i<m.mate[i]
                push!(match,(i,m.mate[i]))
            end
        end
        successful_match = @yield match
        successful_match = isnothing(successful_match) ? match : successful_match
        for (i,j) in successful_match
            rem_edge!(current_graph, i, j)
        end
    end
end

##

"""
\$TYPEDEF

A graph state constructor protocol. For a given graph state with n vertices,
and n registers each containing a communication qubit and a storage qubit,
perform Bell pair entanglement distribution (in the order of rounds prescribed by `graph_builder`),
followed by fusion.

Currently the process is not dynamically adjusted (e.g. due to failure to establish a Bell pair)
and each Bell pair generation is repeatedly attempted until it succeeds.

For example, constructing this graph will require the following steps:

```
   4
   |
   3
  / \
 1───2
```

- entanglers running on 3-4 and 1-2
- only after both entanglers succeed, the states of the comm qubits at 1,2,3,4 are moved into the storage qubits
- entanglers running on 1-3
- fusing from the comm qubits into the storage qubits is executed at 1 and 3
- entanglers running on 2-3
- fusing from the comm qubits into the storage qubits is executed at 2 and 3

### Opportunities for improvement:

- if one of the links in a given round succeeds first, we should execute the corresponding fusion into storage qubits immediately. I.e. if 3-4 succeeds before 1-2, the fusion at 3 and 4 should not wait for the entangler between 1 and 2.
- if one of the links succeeds before another link in the same round, permit other entanglers to run. I.e. if 1-2 succeeds before 3-4, rerun the edge search (in this particular example there is nothing to do, but that is not always the case).

\$TYPEDFIELDS
"""
@kwdef struct GraphStateConstructor <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation # TODO check that
    """a network graph of registers"""
    net::RegisterNet
    """"""
    graph::Graphs.AbstractGraph
    """"""
    nodes::Vector{Int}
    """"""
    communication_slot::Int
    """"""
    storage_slot::Int
end

struct GraphStateStorage
    uuid::Int
    vertex::Int
end
QuantumSavory.Tag(tag::GraphStateStorage) = Tag(GraphStateStorage, tag.uuid, tag.vertex) # TODO these should really be automated

@resumable function (prot::GraphStateConstructor)()
    (;sim, net, graph, nodes, communication_slot, storage_slot) = prot
    entangling_steps_generator = graph_builder(graph)

    slots = vcat(
    [net[n][communication_slot] for n in nodes]...,
    [net[n][storage_slot] for n in nodes]...,
    )
    # lock all
    @yield all(x -> lock(x), slots)

    # prepare all the storage qubits
    for n in nodes
        if !isassigned(net[n][storage_slot])
            initialize!(net[n][storage_slot], X1)
        end
    end

    # run multiple rounds of parallel entangling of independent edges
    while true
        # which edges are we entangling in this round
        current_edges = entangling_steps_generator()
        println(current_edges)
        isnothing(current_edges) && break
        processes = []
        # set up an entangler for each edge
        for (i,j) in current_edges
            nodeA = nodes[i]
            nodeB = nodes[j]
            entangler = EntanglerProt(;
                sim, net,
                nodeA, nodeB,
                chooseA=communication_slot, chooseB=communication_slot,
                tag=nothing,
                pairstate = StabilizerState("ZX XZ"),
                lock=false, rounds=1, attempts=-1, success_prob=1.0, attempt_time=1.0 # TODO parameterize the link time and quality
            )
            process = @process entangler()
            push!(processes, process)
        end
        # wait on all entanglers
        @yield reduce(&, processes)
        # perform fusion at each communication qubit
        for (i,j) in current_edges
            regA = net[nodes[i]]
            regB = net[nodes[j]]
            for reg in (regA, regB)
                apply!((reg[storage_slot],reg[communication_slot]),CNOT)
                meas = project_traceout!(reg[communication_slot], Z)
                if meas == 2
                    apply!(reg[storage_slot], X)
                end
            end
        end
        tag!(net[1][storage_slot], MBQCSetUp, 1) # dummy variable for now

        @debug "Graph state is established."
    end
    for slot in slots
        unlock(slot)
    end

    uuid = rand(Int)
    for (v, n) in enumerate(nodes)
        tag!(net[n][storage_slot], GraphStateStorage, uuid, v)
        #tag!(net[n][storage_slot], GraphStateStorage(uuid, v)) # TODO this should work
    end
end



##

local_topology = state_graph = random_regular_graph(6,2)
@assert is_connected(state_graph) # it is possible to randomly get a disconnected graph, in which case this does not work well
#registers = [Register(2, CliffordRepr()) for i in vertices(local_topology)]
registers = [Register(2) for i in vertices(local_topology)]
net = RegisterNet(local_topology, registers)
sim = get_time_tracker(net)

graphconstructor = GraphStateConstructor(sim, net, state_graph, collect(vertices(local_topology)), 1, 2)

@process graphconstructor()

run(sim, 100)

# TODO these should work for both QuantumOpticsRepr and CliffordRepr
# observable([reg[2] for reg in registers], QuantumClifford.Stabilizer(state_graph)[1])

for i in 1:nv(state_graph)
    o = observable([reg[2] for reg in registers], QuantumOpticsBase.Operator(QuantumClifford.Stabilizer(state_graph)[i]))
    println(o) # should be 1 or -1 (only 1 after we are done with corrections)
end








using ResumableFunctions
using ConcurrentSim
using Revise

using QuantumSavory
using QuantumSavory.ProtocolZoo
import QuantumSavory: Tag

using Logging
global_logger(ConsoleLogger(stderr, Logging.Debug))

const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func_depol(p) = p*perfect_pair_dm + (1-p)*mixed_dm

function noisy_pair_func(F)
    p = (4*F-1)/3
    return noisy_pair_func_depol(p)
end

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

@resumable function MBQC_purification_tracker(sim, net, node)
    nodereg = net[node]
    mb = messagebuffer(net, node)
    while true
        local_tag = query(nodereg, MBQCMeasurement, node, ❓) # waits on the measurement result

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



@resumable function MBQC_purify(sim, net, side, duration=0.1, period=0.1)
    if side == 2
        idx = 5
    else
        idx = 1
    end
    while true
        # checking whether we have entanglements to purify & setup is completed
        query1 = query(net[idx], EntanglementCounterpart, ❓, ❓; locked=false, assigned=true)
        query2 = query(net[idx + 1], EntanglementCounterpart, ❓, ❓; locked=false, assigned=true)
        query3 = query(net[idx], MBQCSetUp)
        if isnothing(query1) || isnothing(query2) || isnothing(query3)
            if isnothing(period)
                @yield onchange_tag(net[idx]) || onchange_tag(net[idx + 1])
            else
                @yield timeout(sim, period)
            end
            continue
        end
        println(query1)
        @debug "Purification starting at side $(side)."

        m1 = project_traceout!(net[idx, storage_slot], X)
        m2 = project_traceout!(net[idx + 2, storage_slot], X)

        if m1 == 2
            apply!(net[idx + 3, storage_slot], Z)
            apply!(net[idx + 1, storage_slot], Z)
        end
        if m2 == 2
            apply!(net[idx + 3, storage_slot], X)
        end
        untag!(query1[1].slot, query1[1].id)
        untag!(query1[2].slot, query1[2].id)
        m = project_traceout!(net[node, storage_slot], X)
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

# Run simulation (infinite rounds)

regL = Register(4)
regR = Register(4)
net = RegisterNet([regL, regR])
sim = get_time_tracker(net)
F = 0.9 # fidelity

@process entangler(sim, net)
@process MBQC_purification_tracker(sim, net, 1)
@process MBQC_purification_tracker(sim, net, 2)

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

# should have been consumed and return nothing
observable([net[1], net[2]], [4, 4], projector(perfect_pair))





### 2-1 purification
@resumable function entangler_fusion(sim, net, nodeA, nodeB, communication_slot, storage_slot, pairstate, rounds=1)
    for round in 1:rounds
        entangler = EntanglerProt(sim, net, nodeA, nodeB; pairstate=pairstate, chooseA=communication_slot, chooseB=communication_slot, success_prob=1.0, attempts=-1, rounds=1)
        p = @process entangler()
        @yield p
        regA = net[nodeA]
        regB = net[nodeB]
        initialize!(net[nodeA][storage_slot], X1)
        initialize!(net[nodeB][storage_slot], X1)  #TODO: check whether it is actually initialized
        for reg in (regA, regB)
            @yield lock(reg[storage_slot]) & lock(reg[communication_slot])
            apply!((reg[storage_slot],reg[communication_slot]),CNOT)
            meas = project_traceout!(reg[communication_slot], Z)
            println(meas)
            if meas == 2
                apply!(reg[storage_slot], X)
            end
            unlock(reg[storage_slot])
            unlock(reg[communication_slot])
        end
    end
end




const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func_depol(p) = p*perfect_pair_dm + (1-p)*mixed_dm

function noisy_pair_func(F)
    p = (4*F-1)/3
    return noisy_pair_func_depol(p)
end


pairstate = perfect_pair
communication_slot = 1
storage_slot = 2
g = Graph(8)

for ij in [(1,3), (2,3), (3,4), (5,7), (6,7), (7,8)]
    add_edge!(g, ij...)
end

registers = [Register(2) for _ in vertices(g)]
net = RegisterNet(g, registers)
sim = get_time_tracker(net)

g1 = induced_subgraph(g, 1:4)[1]
g2 = induced_subgraph(g, 5:8)[1]

#collect(vertices(g)[5:8])

@process entangler_fusion(sim, net, 1, 5, communication_slot, storage_slot, pairstate)
@process entangler_fusion(sim, net, 2, 6, communication_slot, storage_slot, pairstate)
#graphconstructor1 = GraphStateConstructor(sim, net, g1, collect(vertices(g)[1:4]), communication_slot, storage_slot)
#graphconstructor2 = GraphStateConstructor(sim, net, g2, collect(vertices(g)[5:8]), communication_slot, storage_slot)

#@process graphconstructor1()
#@process graphconstructor2()

run(sim, 100)

observable([net[1], net[5]], [1, 1], projector(perfect_pair))
observable([net[1], net[5]], [2, 2], projector(perfect_pair))

observable([net[2], net[6]], [2, 2], projector(perfect_pair))
