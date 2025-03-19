using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using QuantumSymbolics
using QuantumOpticsBase
using QuantumClifford: AbstractStabilizer, Stabilizer, sHadamard, sPhase, sSWAP, canonicalize!, graphstate, sZ
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

        # Initialize a reference register using the graph
        r = Register(n, CliffordRepr())
        initialize!(r[1:n], SProjector(StabilizerState(Stabilizer(graph_jl))))

        # The core represents the key
        key_jl = map(x -> x + 1, Tuple(key)) # +1 because Julia is 1-indexed
        graphdata[key_jl] = (graph_jl, r)
        operationdata[key_jl] = value[2][1,:] # Transition gate sets
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
    apply!(tobeteleported, sHadamard)

    zmeas1 = project_traceout!(tobeteleported, σᶻ)
    zmeas2 = project_traceout!(bellpair[1], σᶻ)
     
    if zmeas2==2 apply!(bellpair[2], X)  end
    if zmeas1==2 apply!(bellpair[2], Z) end

    unlock(qubitA) 
    unlock(bellpair[1]) 
    unlock(bellpair[2])
    

    # msg = Tag(TeleportUpdate, 1, i, 2, i, zmeas2, zmeas1)
    # put!(channel(net, 1=>2; permit_forward=true), msg)
    # @debug "Teleporting qubit $(qubitA.idx) to client node | message=`$(msg)` | time=$(now(sim))"

    @yield timeout(sim, period)
end

@resumable function entangle(sim, net, client, link_success_prob)

    # Set up the entangler protocols at a client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client, nodeB=2, slotB=client,
        success_prob=link_success_prob, rounds=1, attempts=-1, attempt_time=1.0, pairstate=StabilizerState("XX ZZ")
        )
    @yield @process entangler()
end


function order_state!(reg::Register, orderlist::Vector{Int})
    @assert length(reg) == length(orderlist)

    #orderlist = deepcopy(orderlist)
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

function apply_cliffords!(state::AbstractStabilizer, cliffords::Vector{String}, n::Int)
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

@resumable function PiecemakerProt(sim, n, net, graphdata, operationdata, link_success_prob, logging, rounds)

    a = net[1] # switch
    b = net[2] # clients
    ε = 1e-12

    while rounds != 0
        start = now(sim)

        init_run = true
        past_clients = Int[]
        current_clients = Int[]
        order_teleported = Int[]

        chosen_core = () 
        core_found = false # flag to check if the core is present

        sanity_counter = 0 # counter to avoid infinite loops. TODO: is this necessary?
        
        # Initialize the switch storage slots in |+⟩ state
        initialize!(a[n+1:2*n], reduce(⊗, fill(X1,n))) 

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

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
                for core in keys(graphdata)
                    if Set(core) ⊆ Set(past_clients)
                        @debug "Core present, $(core) ⊆ $(past_clients)"
                        chosen_core = core
                        core_found = true
                        @debug "Chosen core: ", chosen_core
                        graph = deepcopy(graphdata[chosen_core][1])#, copy(graphdata[chosen_core][2])
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

        order_state!(b, order_teleported)
        
        
        resultgraph, hadamard_idx, iphase_idx, flips_idx  = graphstate(b.staterefs[1].state[])

        # Compare the graph state with the reference graph state from the input data
        refstate_stabilizers = graphdata[chosen_core][2].staterefs[1].state[]
        coincide = graphstate(refstate_stabilizers)[1] == resultgraph # compare if graphs are equivalent

        # Calculate fidelity
        helperreg = Register(n)
        initialize!(helperreg[1:n], Ket(b.staterefs[1].state[]))
        
        refgraph = graphdata[chosen_core][1]
        fid = map(vertices(refgraph)) do v
            neighs = neighbors(refgraph, v)
            verts = sort([v, neighs...])
            obs = reduce(⊗,[ (i == v) ? σˣ : σᶻ for i in verts ]) # X for the central vertex v, Z for neighbors, Kronecker them together       
            regs = helperreg[sort([v, neighs...])] 
            real(observable(regs, obs)) # calculate the value of the observable
        end
        
        for q in b
            unlock(q)
        end
        while sum(b.stateindices) != 0
            @debug b.stateindices
            for q in b
                traceout!(q)
            end
        end

        # LOGGING: push row into the DataFrame
        push!(
            logging,
            (
                chosen_core, now(sim)-start, coincide, hadamard_idx, iphase_idx, flips_idx, fid...
            )
        )
        rounds -= 1
    end
end

function prepare_sim(graphdata, operationdata, link_success_prob, seed, logging, rounds)
    
    # Set a random seed
    Random.seed!(seed)

    n = nv(graphdata[(2,4)][1]) # number of clients taken from one example graph
    switch = Register(fill(Qubit(), 2*n), fill(CliffordRepr(), 2*n), fill(T2Dephasing(1.0), 2*n)  ) # storage and communication qubits at the switch # fill(T2Dephasing(1.0), 2*n)
    clients = Register(fill(Qubit(), n),  fill(CliffordRepr(), n), fill(T2Dephasing(1.0), n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start teleportation tracker to correct the client qubits
    @process TeleportTracker(sim, net, 2)

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, graphdata, operationdata, link_success_prob, logging, rounds)
    return sim
end

rounds = 1000
seed = 42
all_runs = DataFrame()
for (f, link_success_prob) in enumerate(range(0.5,1,10))

    # Graph state data
    path_to_graph_data = "examples/graphstateswitch/input/7_20250127.pickle"
    graphdata, operationdata = get_graphdata_from_pickle(path_to_graph_data)
    n = nv(graphdata[(2,4)][1]) # number of clients taken from one example graph

    logging = DataFrame(
        chosen_core = Tuple[],
        sim_time    = Float64[],
        coincide    = Float64[],
        H_idx = Any[],
        S_idx = Any[],
        Z_idx = Any[],
    )
    for i in 1:n
        logging[!, Symbol("eig", i)] = Float64[]
    end

    sim = prepare_sim(graphdata, operationdata, link_success_prob, seed, logging, rounds)
    timed = @elapsed run(sim)

    logging[!, :elapsed_time]       .= timed
    logging[!, :link_success_prob]  .= link_success_prob
    logging[!, :seed]               .= seed
    append!(all_runs, logging)
    @info "Link success probability: $(link_success_prob) | Time: $(timed)"
end
#@info all_runs
CSV.write("examples/graphstateswitch/output/sequential_clifford_noisy.csv", all_runs)