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

# Costum function to load the graph data from a python pickle file
function get_graphdata_from_pickle(path)
    
    graphdata = Dict{Tuple, Tuple{Graph, Any}}()
    operationdata = Dict{Tuple, Any}()
    
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
    return graphdata, operationdata
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
    apply!((tobeteleported, bellpair[1]), CNOT)
    apply!(tobeteleported, H)

    zmeas1 = project_traceout!(tobeteleported, σᶻ)
    zmeas2 = project_traceout!(bellpair[1], σᶻ)

    
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

@resumable function entangle(sim, net, client, link_success_prob)

    # Set up the entangler protocols at a client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client, nodeB=2, slotB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0, #retry_lock_time=1.0, #pairstate=StabilizerState("XZ ZX") # Note: generate a two-graph state instead of a bell pair
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

    #orderlist = deepcopy(orderlist)
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

@resumable function PiecemakerProt(sim, n, net, graphdata, link_success_prob, logging, rounds)

    a = net[1] # switch
    b = net[2] # clients
    ε = 1e-12 # infinitesimal additional time step to wait for entanglement generation to complete

    while rounds != 0
        start = now(sim)

        init_run = true
        past_clients = Int[]
        order_teleported = Int[]

        sanity_counter = 0 # sanity counter to avoid excessive iterations. TODO: is this necessary?
        
        # Initialize the switch storage slots in |+⟩ state
        initialize!(a[n+1:2*n], reduce(⊗, fill(X1,n))) 

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        while true
            graph, refstate = copy(graphdata[(2,4)][1]), copy(graphdata[(2,4)][2])
            
            # Get the successful clients
            activeclients = queryall(b, EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
            
            if isempty(activeclients)
                @debug "No active clients, waiting for entanglement"
                @yield timeout(sim, 1.0+ε) # TODO: is there a better way to do this?
                continue
            end
            # Collect active clients
            for c in activeclients
                if c.slot.idx ∉ past_clients
                    push!(past_clients, c.slot.idx)
                end
            end

            # If all clients have been entangled teleport the qubits
            if length(past_clients) == n
                @debug "All clients entangled, teleporting qubits"

                # Apply CZ gates according to graph and teleport the remaining qubits
                for i in past_clients
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

        order_state!(b, order_teleported)

        @debug b.staterefs[1].state[]
        fidelity = express(dagger(b.staterefs[1].state[]))*refstate
        @debug "Fidelity: ", fidelity
        while sum(b.stateindices) != 0
            @debug b.stateindices
            for q in b
                traceout!(q)
            end
        end
        for q in b
            unlock(q)
        end

        # Logging outcome
        push!(
            logging,
            (
                now(sim)-start, abs(fidelity)^2
            )
        )
        rounds -= 1
    end
end

function prepare_sim(path_to_graph_data, link_success_prob, seed, logging, rounds)
    
    # Set a random seed
    Random.seed!(seed)

    # Graph state
    graphdata, _ = get_graphdata_from_pickle(path_to_graph_data)

    n = nv(graphdata[(2,4)][1]) # number of clients taken from one example graph
    switch = Register(2*n) # storage and communication qubits at the switch
    clients = Register(n) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start teleportation tracker to correct the client qubits
    @process TeleportTracker(sim, net, 2)

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, graphdata, link_success_prob, logging, rounds)
    return sim
end

rounds = 10
seed = 42

all_runs = DataFrame()
for link_success_prob in range(0.1,1,10)
    # Run simulation
    logging = DataFrame(
        sim_time    = Float64[],
        fidelity    = Float64[]
    )

    sim = prepare_sim("examples/graphstateswitch/input/7.pickle", link_success_prob, seed, logging, rounds)
    timed = @elapsed run(sim)
    @debug logging

    logging[!, :elapsed_time]       .= timed
    logging[!, :link_success_prob]  .= link_success_prob
    logging[!, :seed]               .= seed
    append!(all_runs, logging)
end
@info all_runs
#CSV.write("examples/graphstateswitch/output/canonical.csv", all_runs)