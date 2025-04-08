using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using QuantumOpticsBase
using ResumableFunctions
using NetworkLayout
using Random, StatsBase
using Graphs, GraphRecipes

using DataFrames, StatsPlots
using CSV

using QuantumClifford: AbstractStabilizer, Stabilizer, graphstate, sHadamard, sSWAP, stabilizerview, canonicalize!, sCNOT

using PyCall
@pyimport pickle
@pyimport networkx

"""
    get_graphdata_from_pickle(path)
    Load the graph data from a pickle file and convert it to Julia format.
    Args:
        path (str): Path to the pickle file containing graph data.
    Returns:
        graphdata (Dict): Dictionary mapping tuples to tuples of Graph and Register.
        operationdata (Dict): Dictionary mapping tuples to transition gate sets.
"""
function get_graphdata_from_pickle(path)
    
    graphdata = Dict{Tuple, Tuple{Graph, Any}}()
    operationdata = Dict{Tuple, Any}()
    
    # Load the graph data in python from pickle file
    graphdata_py = pickle.load(open(path, "r"))
    
    for (key, value) in graphdata_py # value = [lc equivalent graph, transition gates
        graph_py = value[1]
        n = networkx.number_of_nodes(graph_py)

        # Generate graph in Julia and apply the CZ gates to reference register
        graph_jl = Graph()
        add_vertices!(graph_jl, n)
        for edge in value[1].edges
            edgejl = map(x -> x + 1, Tuple(edge)) # +1 because Julia is 1-indexed
            add_edge!(graph_jl, edgejl) 
        end

        # Initialize a perfect reference register using the graph data
        r = Register(n, CliffordRepr())
        initialize!(r[1:n], SProjector(StabilizerState(Stabilizer(graph_jl))))

        # The core represents the key
        key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
        graphdata[key_jl] = (graph_jl, r)
        operationdata[key_jl] = value[2][1,:] # Transition gate sets
    end
    return graphdata, operationdata
end

"""
    TeleportTracker(sim, net, node)
    Track the teleportation of qubits in a network simulation.
    
    Args:
        sim: The simulation object.
        net: The network object.
        node: The node to track.
"""
@resumable function TeleportTracker(sim, net, node, mb)
    nodereg = net[node]
    job_done = false
    while !job_done
        # Look for EntanglementUpdate? message sent to us
        @yield wait(mb)
        while true
            msg = querydelete!(mb, TeleportUpdate, ❓, ❓, ❓, ❓, ❓, ❓)
            isnothing(msg) && break

            (src, (_, past_node, past_slot, local_node, local_slot, zcorrection1, zcorrection2)) = msg

            @assert local_node == node "TeleportTracker @$(node).$(local_slot): Receiving node is not the same as the local node $(local_node) != $(node)"
            @debug "TeleportTracker @$(node).$(local_slot): Received from $(past_node).$(past_slot) | message=`$(msg.tag)` | time=$(now(sim))"
            
            localslot = nodereg[local_slot]

            # Apply Pauli corrections
            @yield lock(localslot)
            if zcorrection1==2
                apply!(localslot, X)
            end
            if zcorrection2==2
                apply!(localslot, Z)
            end
            unlock(localslot)
            
            job_done = true
            job_done && break
        end
    end
end

@resumable function ProjectTracker(sim, net, node, mb)
    nodereg = net[node]
    job_done = false
    while !job_done
        # Look for EntanglementUpdate? message sent to us
        @yield wait(mb)
        while true
            msg = querydelete!(mb, TeleportUpdate, ❓, ❓, ❓, ❓, ❓, ❓)
            isnothing(msg) && break

            (src, (_, past_node, past_slot, local_node, local_slot, zcorrection1, zcorrection2)) = msg

            @assert local_node == node "TeleportTracker @$(node).$(local_slot): Receiving node is not the same as the local node $(local_node) != $(node)"
            @debug "TeleportTracker @$(node).$(local_slot): Received from $(past_node).$(past_slot) | message=`$(msg.tag)` | time=$(now(sim))"
            
            localslot = nodereg[local_slot]

            # Apply Pauli corrections
            @yield lock(localslot)
            if zcorrection1==2
                apply!(localslot, Z)
            end
            # if zcorrection2==2
            #     apply!(localslot, Z)
            # end
            unlock(localslot)
            
            job_done = true
            job_done && break
        end
    end
end

@resumable function projective_teleport(sim, net, switch_reg::Register, client_reg::Register, graph::Graph, i::Int; period::Float64=1.0)

    reg = switch_reg
    graph_local_copy = copy(graph)
    neighbors_client = neighbors(graph_local_copy, i)
    for neighbor in neighbors_client
        @debug "Applying CZ gate between $(i) and $(neighbor)"
        @yield lock(reg[i]) & lock(reg[neighbor])
        apply!((reg[i], reg[neighbor]), ZCZ) 
        unlock(reg[i])
        unlock(reg[neighbor])
        rem_edge!(graph, i, neighbor) # remove edge from the graph to keep track of the applied CZ gates
        @debug "Removed edge between $(i) and $(neighbor), edges left: $(collect(edges(graph)))"
    end
    
    switch_qubit = reg[i]
    @yield lock(switch_qubit)
    measi = signed(project_traceout!(switch_qubit, σˣ))
    unlock(switch_qubit) 

    # @yield lock(client_reg[i])
    # if measi == 2
    #     apply!(client_reg[i], Z)
    # end
    # unlock(client_reg[i])

    msg = Tag(TeleportUpdate, 1, i, 2, i, 1, measi)
    put!(channel(net, 1=>2; permit_forward=true), msg)
    @debug "Teleporting qubit $(qubitA.idx) to client node | message=`$(msg)` | time=$(now(sim))"

    @yield timeout(sim, period)
end

"""
    teleport(sim, net, switch_reg, client_reg, graph, i, period=1.0)
    Teleport a qubit from the switch to the client node.
    
    Args:
        sim: The simulation object.
        net: The network object.
        switch_reg: The register at the switch node.
        client_reg: The register at the client node.
        graph: The graph representing the entangled state.
        i: The index of the qubit to teleport.
        period: The time period assumed for the teleportation process to take.
"""
@resumable function teleport(sim, net, switch_reg::Register, client_reg::Register, graph::Graph, i::Int; period::Float64=1.0)
    n = nv(graph)
    reg = switch_reg
    graph_local_copy = copy(graph)
    neighbors_client = neighbors(graph_local_copy, i)
    for neighbor in neighbors_client
        @debug "Applying CZ gate between $(i) and $(neighbor)"
        @yield lock(reg[n+i]) & lock(reg[n+neighbor])
        apply!((reg[n+i], reg[n+neighbor]), ZCZ) 
        rem_edge!(graph, i, neighbor) # remove edge from the graph to keep track of the applied CZ gates
        @debug "Removed edge between $(i) and $(neighbor), edges left: $(collect(edges(graph)))"
        unlock(reg[n+i])
        unlock(reg[n+neighbor])
    end
    
    qubitA = switch_reg[n+i]
    bellpair = (switch_reg[i], client_reg[i])
    @yield  lock(qubitA) & lock(bellpair[1]) & lock(bellpair[2])
    @debug "Teleporting qubit $(qubitA.idx) to client node"
    tobeteleported = qubitA
    apply!((tobeteleported, bellpair[1]), sCNOT)
    apply!(tobeteleported, sHadamard)

    zmeas1 = signed(project_traceout!(tobeteleported, σᶻ)) # TODO: signed is used to convert  signed integer Int64, is this necessary?
    zmeas2 = signed(project_traceout!(bellpair[1], σᶻ)) # see source file src/tags.jl for defintion of Tags

    # if zmeas2==2 apply!(bellpair[2], X) end # instead of doing this 'locally' we send the correction to the client
    # if zmeas1==2 apply!(bellpair[2], Z) end # see below

    unlock(qubitA) 
    unlock(bellpair[1]) 
    unlock(bellpair[2])
    
    msg = Tag(TeleportUpdate, 1, i, 2, i, zmeas2, zmeas1)
    put!(channel(net, 1=>2; permit_forward=true), msg)
    @debug "Teleporting qubit $(qubitA.idx) to client node | message=`$(msg)` | time=$(now(sim))"

    @yield timeout(sim, period)
end

"""
    entangle(sim, net, client, link_success_prob)
    Set up the entangler protocols at a client.
    
    Args:
        sim: The simulation object.
        net: The network object.
        client: The client node to set up the entangler for.
        link_success_prob: The probability of successful entanglement generation.
"""
@resumable function entangle(sim, net, client, link_success_prob)

    # Set up the entangler protocols at a client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client, nodeB=2, slotB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0,
        )
    @yield @process entangler()
    msg = Tag(EntanglementCounterpart, 1, client)
    put!(channel(net, 2=>1; permit_forward=false), msg)
end

"""
    order_state!(reg, orderlist)
    Reorder the qubits in the register according to the orderlist.
    
    Args:
        reg: The register containing the qubits.
        orderlist: A list of integers representing the desired order of qubits.
"""
function order_state!(reg::Register, orderlist)
    @assert length(reg) == length(orderlist) "Length of register and orderlist must be the same"

    # Loop over each index i
    for i in 1:length(orderlist)
        # If the qubit at position i isn't i, swap it with wherever qubit i lives
        while orderlist[i] != i
            # Find which position holds the qubit i
            correct_index = findfirst(==(i), orderlist)

            # Swap the register qubits physically
            apply!((reg[i], reg[correct_index]), sSWAP)

            # Swap the entries in orderlist
            orderlist[i], orderlist[correct_index] = orderlist[correct_index], orderlist[i]
        end
    end
end

function order_state!(state::AbstractStabilizer, current_order::Vector{Int})
    # Loop over each index 
    for i in 1:length(current_order)
        # If the qubit at position i isn't i, swap it with wherever qubit i lives
        while current_order[i] != i
            @debug "current order $(current_order)"
            # Find which position holds the qubit i
            correct_index = findfirst(==(i), current_order)

            # Swap the register qubits physically
            apply!(state, sSWAP(current_order[i], current_order[correct_index]); phases=true)
            current_order[i], current_order[correct_index] = current_order[correct_index], current_order[i]
            @debug "swaped $((i,correct_index)) to get $(collect(edges(graphstate(state)[1])))"
        end

    end
    @debug "current order $(current_order)"
end

"""
    apply_cliffords!(reg::Register, cliffords::Vector{String})
    Apply the Clifford gates to the register according to given list of gates.
    
    Args:
        reg: The register containing the qubits.
        cliffords: A vector of strings representing the Clifford gates to be applied.
"""
function apply_cliffords!(reg::Register, cliffords::Vector{String})
    mapping = Dict(
        'S' => sPhase,
        'H' => sHadamard,
    )
    for (i, clifford) in enumerate(cliffords)
        for gate in reverse(clifford)
            if gate == 'I'
                continue
            end
            apply!(reg[i], mapping[gate])
            @debug "Applied $(gate) to qubit $(i)"
            
        end
    end
end

"""
    apply_cliffords!(state::AbstractStabilizer, cliffords::Vector{String}, n::Int)
    Alternative to previous function. Apply the Clifford gates to the stabilizer state according to given list of gates.
    
    Args:
        state: The stabilizer state containing the qubits.
        cliffords: A vector of strings representing the Clifford gates to be applied.
        n: The number of qubits in the state.
"""
function apply_cliffords!(state::AbstractStabilizer, cliffords::Vector{String})
    for (i, clifford) in enumerate(cliffords)
        for gate in reverse(clifford)
            if gate == 'I'
                continue
            elseif gate == 'H'
                apply!(state, sHadamard(i); phases=true)
            elseif gate == 'S'
                apply!(state, sPhase(i); phases=true)
            end
            @debug "Applied $(gate) to qubit $(i)"
        end
    end
end