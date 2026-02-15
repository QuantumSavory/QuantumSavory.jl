module MBQCEntanglementDistillation

using QuantumSavory
import QuantumSavory: Tag
using QuantumSavory.ProtocolZoo: AbstractProtocol, EntanglerProt
using QuantumSavory.CircuitZoo: Fusion

using DocStringExtensions

using ConcurrentSim
using ResumableFunctions

using QuantumClifford: stab_to_gf2, graphstate, Stabilizer, MixedDestabilizer, logicalxview, logicalzview
using QuantumClifford.ECC: CSS, parity_checks

import HiGHS
using JuMP: JuMP, MOI
using Graphs
using GraphsMatching: maximum_weight_matching

export
    # Graph state construction
    graph_builder, GraphStateConstructor, GraphStateStorage,
    # MBQC Purification
    GraphToResource, PurifierBellMeasurements, PurifierBellMeasurementResults,
    PurifiedEntanglementCounterpart, MBQCPurificationTracker

## Graph State Construction


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
    """the graph state to be constructed, with vertices corresponding to entries in `nodes`"""
    graph::Graphs.AbstractGraph
    """nodes at which the graph state is distributed"""
    nodes::Vector{Int}
    """slot for entanglement generation (e.g. electron spin)"""
    communication_slot::Int
    """slot for storage (e.g. nuclear spin)"""
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

            Fusion()(regA, regB, communication_slot, storage_slot)
        end

        @debug "[$(now(sim))]: GraphStateConstructor: graph state is established"
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


#
# MBQC Purification Protocols
#

"""
\$TYPEDEF

Apply local operations to a graph state to convert it to a locally-equivalent general stabilizer state.

It is parameterized by the indices of the Hadamard, inverse Phase, and Z gates that need to be performed,
e.g. as provided by the `graphstate` function in QuantumClifford.jl.

There are constraints to how this protocol works, chiefly it is an "instant classical communication" protocol.
It is useful in situations where all "registers" or "nodes" are in the same fridge, controlled by a single controller.

\$TYPEDFIELDS
"""
@kwdef struct GraphToResource <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """nodes at which the graph state is distributed"""
    nodes::Vector{Int}
    """slot at each node where the graph state qubit is stored"""
    slot::Int
    """indices where Hadamard corrections are to be applied"""
    hadamard_idx::Vector{Int}
    """indices where inverse Phase corrections are to be applied"""
    iphase_idx::Vector{Int}
    """indices where Z corrections are to be applied"""
    flips_idx::Vector{Int}
end

@resumable function (prot::GraphToResource)()
    (;sim, net, nodes, slot, hadamard_idx, iphase_idx, flips_idx) = prot

    for i in flips_idx
        error("`GraphToResource` does not support non-CSS codes as resources states yet -- Z flips are not available")
    end

    for i in iphase_idx
        error("`GraphToResource` does not support non-CSS codes as resources states yet -- inverse Phases are not available")
    end

    for i in hadamard_idx
        apply!(net[nodes[i]][slot], H)
    end
end

"""
\$TYPEDEF

Message containing the results of Bell measurements performed during purification.

\$TYPEDFIELDS
"""
@kwdef struct PurifierBellMeasurementResults
    """the node that performed the measurements"""
    node::Int
    """bit-packed XX measurement results"""
    measurements_XX::Int64
    """bit-packed ZZ measurement results"""
    measurements_ZZ::Int64
end
Base.show(io::IO, msg::PurifierBellMeasurementResults) = print(io, "PurifierBellMeasurementResults(node=$(msg.node), XX=$(bitstring(msg.measurements_XX)), ZZ=$(bitstring(msg.measurements_ZZ)))")
Tag(msg::PurifierBellMeasurementResults) = Tag(PurifierBellMeasurementResults, msg.node, msg.measurements_XX, msg.measurements_ZZ)

"""
\$TYPEDEF

Apply Bell measurements to a number of local nodes, bitpack the results in a single `Int64` and send that information to a remote location.

There are constraints to how this protocol works, chiefly it is an "instant classical communication" protocol.
It is useful in situations where all "registers" or "nodes" are in the same fridge, controlled by a single controller.

\$TYPEDFIELDS
"""
@kwdef struct PurifierBellMeasurements <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """nodes at which the Bell measurements will be happening"""
    nodes::Vector{Int}
    """"Chief" node for our local set of nodes, the source of the bitpacked message"""
    local_chief_idx::Int
    """"Chief" node for the remote set of nodes, the destination node for the bitpacked message"""
    remote_chief_idx::Int
    """slot on which the X measurement is performed (same for all nodes), the control of the CNOT"""
    x_slot::Int
    """slot on which the Z measurement is performed (same for all nodes), the target of the CNOT"""
    z_slot::Int
end

@resumable function (prot::PurifierBellMeasurements)()
    (;sim, net, nodes, local_chief_idx, remote_chief_idx, x_slot, z_slot) = prot

    n = length(nodes)

    slots = []
    for i in 1:n
        push!(slots, net[nodes[i]][x_slot])
        push!(slots, net[nodes[i]][z_slot])
    end

    @yield reduce(&, [lock(slot) for slot in slots])

    s = []
    t = []
    for i in 1:n
        _x_slot = net[nodes[i]][x_slot]
        _z_slot = net[nodes[i]][z_slot]

        apply!((_x_slot, _z_slot), CNOT)
        mX = project_traceout!(_x_slot, X)
        mZ = project_traceout!(_z_slot, Z)

        push!(s, mX - 1)  # Convert from {1,2} to {0,1}
        push!(t, mZ - 1)
    end

    for slot in slots
        unlock(slot)
    end

    s_int = sum(bit * 2^(i-1) for (i, bit) in enumerate(s))
    t_int = sum(bit * 2^(i-1) for (i, bit) in enumerate(t))

    msg = PurifierBellMeasurementResults(node=local_chief_idx, measurements_XX=s_int, measurements_ZZ=t_int)
    @debug "[$(now(sim))]: PurifierBellMeasurements at node $(local_chief_idx) completed measurements XX=$(s_int) ZZ=$(t_int)"

    tag!(net[local_chief_idx][z_slot], Tag(msg))
    put!(channel(net, local_chief_idx=>remote_chief_idx; permit_forward=true), msg)
end

"""
\$TYPEDEF

A tag indicating a purified entanglement with a remote node.

\$TYPEDFIELDS
"""
@kwdef struct PurifiedEntanglementCounterpart
    """the remote node we are entangled to after purification"""
    remote_node::Int
    """the slot in the remote node"""
    remote_slot::Int
end
Base.show(io::IO, tag::PurifiedEntanglementCounterpart) = print(io, "PurifiedEntanglementCounterpart($(tag.remote_node).$(tag.remote_slot))")
Tag(tag::PurifiedEntanglementCounterpart) = Tag(PurifiedEntanglementCounterpart, tag.remote_node, tag.remote_slot)

"""
\$TYPEDEF

Track results of Bell measurements sent from other locations, deciding how to proceed. The two options are:

- success: tag the purified Bell pairs with `PurifiedEntanglementCounterpart` tag
- failure: clean up all involved qubit slots

\$TYPEDFIELDS
"""
@kwdef struct MBQCPurificationTracker <: AbstractProtocol
    """time-and-schedule-tracking instance from `ConcurrentSim`"""
    sim::Simulation
    """a network graph of registers"""
    net::RegisterNet
    """nodes storing the resource state -- first `n` correspond to initial Bell pairs, and last `k` correspond to purified Bell pairs"""
    nodes::Vector{Int}
    """number of initial Bell pairs"""
    n::Int
    """"Chief" node for our local set of nodes"""
    local_chief_idx::Int
    """"Chief" node for the remote set of nodes"""
    remote_chief_idx::Int
    """X parity check matrix of the code"""
    H1::Matrix{Int}
    """Z parity check matrix of the code"""
    H2::Matrix{Int}
    """logical X operators of the code"""
    logxs::Stabilizer
    """logical Z operators of the code"""
    logzs::Stabilizer
    """slot for entanglement generation (e.g. electron spin)"""
    communication_slot::Int
    """slot for storage (e.g. nuclear spin)"""
    storage_slot::Int
    """whether to perform correction operations after receiving measurement messages"""
    correct::Bool = false
end

@resumable function (prot::MBQCPurificationTracker)()
    (;sim, net, nodes, n, local_chief_idx, remote_chief_idx, H1, H2, logxs, logzs, communication_slot, storage_slot, correct) = prot

    k = length(nodes) - n
    mb = messagebuffer(net, local_chief_idx)

    while true
        # Wait for local measurement result
        local_tag = query(net[local_chief_idx][storage_slot], PurifierBellMeasurementResults, local_chief_idx, ❓, ❓)

        if isnothing(local_tag)
            @yield onchange(net[local_chief_idx][storage_slot], Tag)
            continue
        end

        # Wait for remote measurement result
        msg = query(mb, PurifierBellMeasurementResults, remote_chief_idx, ❓, ❓)
        if isnothing(msg)
            @debug "[$(now(sim))]: MBQCPurificationTracker at node $(local_chief_idx) waiting for remote message"
            @yield onchange(mb)
            @debug "[$(now(sim))]: MBQCPurificationTracker at node $(local_chief_idx) received message"
            continue
        end

        msg_data = querydelete!(mb, PurifierBellMeasurementResults, ❓, ❓, ❓)
        local_measurements_XX = local_tag.tag[3]
        local_measurements_ZZ = local_tag.tag[4]
        _, (_, remote_node, remote_measurements_XX, remote_measurements_ZZ) = msg_data

        s_int = xor(local_measurements_XX, remote_measurements_XX)
        t_int = xor(local_measurements_ZZ, remote_measurements_ZZ)

        s = [((s_int >> (i-1)) & 1) for i in 1:n]
        t = [((t_int >> (i-1)) & 1) for i in 1:n]
        syndrome = (H1*s + H2*t) .% 2

        if syndrome == zeros(Int, length(syndrome))
            @debug "[$(now(sim))]: MBQCPurificationTracker purification successful"

            if correct
                @debug "[$(now(sim))]: MBQCPurificationTracker applying corrections"

                logxs_binary = stab_to_gf2(logxs)
                logzs_binary = stab_to_gf2(logzs)
                X_1 = logxs_binary[:, 1:n]
                X_2 = logxs_binary[:, n+1:end]
                Z_1 = logzs_binary[:, 1:n]
                Z_2 = logzs_binary[:, n+1:end]

                r_b = (sum(Z_1 .* Z_2, dims=2)[:]) .% 2
                r_p = (sum(X_1 .* X_2, dims=2)[:]) .% 2

                β = (Z_1*s + Z_2*t + r_b) .% 2
                φ = (X_1*s + X_2*t + r_p) .% 2

                for i in 1:k
                    if β[i] == 1
                        apply!(net[nodes[n + i]][storage_slot], X)
                    end
                    if φ[i] == 1
                        apply!(net[nodes[n + i]][storage_slot], Z)
                    end
                end

                @debug "[$(now(sim))]: MBQCPurificationTracker corrections completed"
            end

            # Tag purified pairs
            for i in n:n+k-1
                tag!(net[local_chief_idx + i][storage_slot], PurifiedEntanglementCounterpart, remote_chief_idx + i, storage_slot)
            end
        else
            @debug "[$(now(sim))]: MBQCPurificationTracker purification failed syndrome=$(syndrome)"
            untag!(local_tag.slot, local_tag.id)
            for i in nodes
                traceout!(net[i][communication_slot])
                traceout!(net[i][storage_slot])
            end
        end
    end
end

end
