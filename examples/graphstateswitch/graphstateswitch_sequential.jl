using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions
using NetworkLayout
using Random, StatsBase
using Graphs
using PyCall
using DataFrames, StatsPlots
using CSV


@pyimport pickle
@pyimport networkx


# Costum function to load the graph data
function get_graphdata_from_pickle(path, graphdata::Dict{Tuple, Tuple{Graph, Any}}, operationdata::Dict{Tuple, Any})
    
    # Load the graph data in python from pickle file
    graphdata_py = pickle.load(open(path, "r"))
    
    for (key, value) in graphdata_py # value = [lc equivalent graph, transition gates
        graph_py = value[1]
        n = networkx.number_of_nodes(graph_py)

        # Initialize a reference register in |+⟩ state
        r = Register(n)
        initialize!(r[1:n], reduce(⊗, fill(X1,n)))  

        # Generate graph in Julia and apply the CZ gates to reference register
        graph_jl = Graph()
        add_vertices!(graph_jl, n)
        for edge in value[1].edges
            edgejl = map(x -> x + 1, Tuple(edge)) # +1 because Julia is 1-indexed
            add_edge!(graph_jl, edgejl) 
            apply!((r[edgejl[1]], r[edgejl[2]]), ZCZ)
        end

        # The core represents the key
        key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
        graphdata[key_jl] = (graph_jl, copy(r.staterefs[1].state[]))
        operationdata[key_jl] = value[2][1,:] # Transition gates
    end
end

@resumable function TeleportTracker(sim, net, node)
    nodereg = net[node]
    mb = messagebuffer(net, node)
    while true
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
        end
    end
end

@resumable function teleport(sim, net, switch_reg::Register, client_reg::Register, graph::Graph, i::Int, period=1.0)
    n = nv(graph)
    reg = switch_reg
    neighbors_client = copy(neighbors(graph, i))
    for neighbor in neighbors_client
        @debug "Applying CZ gate between $(i) and $(neighbor)"
        @yield lock(reg[n+i]) & lock(reg[n+neighbor])
        apply!((reg[n+i], reg[n+neighbor]), ZCZ) 
        rem_edge!(graph, i, neighbor) # remove the edge from the graph
        @debug "Removed edge between $(i) and $(neighbor), edges left: $(collect(edges(graph)))"
        unlock(reg[n+i])
        unlock(reg[n+neighbor])
    end
    
    qubitA = switch_reg[n+i]
    bellpair = (switch_reg[i], client_reg[i])
    @yield  lock(qubitA) & lock(bellpair[1]) & lock(bellpair[2])
    @debug "Teleporting qubit $(qubitA.idx) to client node"
    tobeteleported = qubitA
    apply!((tobeteleported, bellpair[1]), CNOT)
    apply!(tobeteleported, H)

    zmeas1 = project_traceout!(tobeteleported, σᶻ)
    zmeas2 = project_traceout!(bellpair[1], σᶻ)
    
    # if zmeas2==2 apply!(bellpair[2], X) end
    # if zmeas1==2 apply!(bellpair[2], Z) end

    unlock(qubitA) 
    unlock(bellpair[1]) 
    unlock(bellpair[2])
    

    msg = Tag(TeleportUpdate, 1, i, 2, i, zmeas2, zmeas1)
    put!(channel(net, 1=>2; permit_forward=true), msg)
    @debug "Teleporting qubit $(qubitA.idx) to client node | message=`$(msg)` | time=$(now(sim))"

    @yield timeout(sim, period)
end

@resumable function entangle(sim, net, client, link_success_prob)

    # Set up the entangler protocols at each client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client, nodeB=2, slotB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0 #pairstate=StabilizerState("XZ ZX") # Note: generate a two-graph state instead of a bell pair
        )
    @yield @process entangler()
end


function SWAP!(reg, idx1, idx2)
    q1 = reg[idx1]
    q2 = reg[idx2]
    apply!((q1, q2), CNOT)
    apply!((q2, q1), CNOT)
    apply!((q1, q2), CNOT)
end

function order_state!(reg, orderlist)
    @assert length(reg) == length(orderlist)

    # Loop over each index i
    for i in 1:length(orderlist)
        # If the qubit at position i isn't i, swap it with wherever qubit i lives
        while orderlist[i] != i
            # Find which position holds the qubit i
            correct_index = findfirst(==(i), orderlist)

            # Swap the register qubits physically
            SWAP!(reg, correct_index, i)

            # Swap the entries in orderlist
            orderlist[i], orderlist[correct_index] = orderlist[correct_index], orderlist[i]
        end
    end
end

@resumable function PiecemakerProt(sim, n, net, testgraphdata, logging, seed, link_success_prob)

    a = net[1] # switch
    b = net[2] # clients
    init_run = true
    past_clients = Int[]
    current_clients = Int[]
    order_teleported = Int[]
    ε = 1e-12

    chosen_core = () 
    core_found = false # flag to check if the core is present

    sanity_counter = 0 # counter to avoid infinite loops. TODO: is this necessary?
    
    while true
        # Get the successful clients
        activeclients = queryall(b, EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
        
        if isempty(activeclients)
            @debug "No active clients, waiting for entanglement"
            @yield timeout(sim, 1.0+ε)
            continue
        end
        # Collect active clients
        for c in activeclients
            if c.slot.idx ∉ past_clients
                push!(past_clients, c.slot.idx)
                push!(current_clients, c.slot.idx)
            end
        end
        @debug "Currently active clients: ", current_clients

        if !core_found
            for core in keys(testgraphdata)
                if Set(core) ⊆ Set(past_clients)
                    @debug "Core present, $(core) ⊆ $(past_clients)"
                    chosen_core = core
                    core_found = true
                    @debug "Chosen core: ", chosen_core
                    graph, refstate = testgraphdata[chosen_core]
                    break # core is found no need for further checking
                end
            end
        else
            @debug "Chosen core: ", chosen_core
            # Teleportation protocol: apply CZ gates according to graph and measure out qubits that are entangled and not part of the core

            for i in current_clients
                if !(i in chosen_core)
                    @yield @process teleport(sim, net, a, b, graph, i)
                    push!(order_teleported, i)
                end
            end
            current_clients = []


        end
        # If all clients have been entangled teleport the core qubits
        if length(order_teleported) == n-length(chosen_core)
            @debug "All non-core clients teleported, teleporting core qubits"

            # Apply CZ gates according to graph and teleport the remaining qubits
            for i in chosen_core
                @yield @process teleport(sim, net, a, b, graph, i)
                push!(order_teleported, i)
            end
            break
        end

        sanity_counter += 1 # TODO: make this prettier?
        if sanity_counter > 1000
            @debug "Link success probability might be too small, maximum iterations encountered. Terminate."
            return
        end
        !init_run && @yield timeout(sim, 1.)
        init_run = false
    end
    @debug "Ordered indices of teleported storage qubits to the client: $(b.stateindices)"
    @yield reduce(&, [lock(q) for q in b])
    order_state!(b, b.stateindices)

    fidelity = dagger(b.staterefs[2].state[])*refstate
    @info "Fidelity: ", fidelity
    for q in b
        unlock(q)
    end

    # LOGGING: push row into the DataFrame
    push!(
        logging,
        (chosen_core, link_success_prob, now(sim), abs(fidelity)^2, seed
        )
    )
end

function prepare_sim(path_to_graph_data, link_success_prob, seed, logging)
    
    # Set a random seed
    Random.seed!(seed)

    # Graph state
    graphdata = Dict{Tuple, Tuple{Graph, Any}}()
    operationdata = Dict{Tuple, Any}()
    path_to_graph_data = get_graphdata_from_pickle(path_to_graph_data, graphdata, operationdata)

    @info operationdata

    n = nv(graphdata[(2,4)][1]) # number of clients taken from one example graph
    switch = Register(2*n) # storage and communication qubits at the switch
    clients = Register(n) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Initialize the switch storage slots in |+⟩ state
    initialize!(switch[n+1:2*n], reduce(⊗, fill(X1,n))) 

    # Start teleportation tracker to correct the client qubits
    @process TeleportTracker(sim, net, 2)

    # Start entanglement generation for each client
    clients_successful = []
    for i in 1:n
        successful_entanglement = @process entangle(sim, net, i, link_success_prob)
        push!(clients_successful, successful_entanglement)
    end

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, graphdata, logging, seed, link_success_prob)
    return sim
end


# Run simulation
logging = DataFrame(
    chosen_core = Tuple[],
    link_success_prob = Float64[],
    sim_time    = Float64[],
    fidelity   = Float64[],
    seed = Int[],
)

# elapsed_times = Float64[]
# for link_success_prob in range(0.01, 1.0, length=10)
#     for seed in range(1,1000)
#         sim = prepare_sim("examples/graphstateswitch/input/7.pickle", link_success_prob, seed, logging)
#         timed = @elapsed run(sim)
#         push!(elapsed_times, timed)
#     end
#     @info "Link success probability: $(link_success_prob)"
# end

# logging[!,:elapsed_time] = elapsed_times
# display(logging)
# CSV.write("examples/graphstateswitch/output/sequential.csv", logging)

sim = prepare_sim("examples/graphstateswitch/input/7.pickle", 0.1, 42, logging)
timed = @elapsed run(sim)
println("Elapsed time: ", timed)