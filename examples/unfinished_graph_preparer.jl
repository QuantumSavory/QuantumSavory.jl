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

    slots = []
    # TODO: debug
    # comm_slots = [net[n][communication_slot] for n in nodes]
    # stor_slots = [net[n][storage_slot] for n in nodes]
    # append!(slots, comm_slots)
    # append!(slots, stor_slots)
    for n in nodes
        push!(slots, net[n][communication_slot])
        push!(slots, net[n][storage_slot])
    end


    # lock all
    @yield reduce(&, [lock(slot) for slot in slots])

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
                uselock=false, rounds=1, attempts=-1, success_prob=1.0, attempt_time=1.0 # TODO parameterize the link time and quality
            )
            process = @process entangler()
            push!(processes, process)
        end
        # wait on all entanglers
        @yield reduce(&, processes)
        # perform fusion at each communication qubit
        for (i, j) in current_edges
            regA = net[nodes[i]]
            regB = net[nodes[j]]

            # CZ
            apply!((regA[storage_slot], regA[communication_slot]), CPHASE)
            apply!((regB[storage_slot], regB[communication_slot]), CPHASE)

            mA = project_traceout!(regA[communication_slot], X)
            mB = project_traceout!(regB[communication_slot], X)

            if mA == 2
                apply!(regB[storage_slot], Z)
            end
            if mB == 2
                apply!(regA[storage_slot], Z)
            end
        end

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
