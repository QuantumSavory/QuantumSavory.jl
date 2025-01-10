using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions
using NetworkLayout
using Random, StatsBase
using Graphs
using PyCall

@pyimport pickle
@pyimport networkx

# @info express(FockState(0, FockBasis(1))⊗ FockState(1, FockBasis(1)) ⊗ FockState(1, FockBasis(1)))
# @info express(FockState(1, FockBasis(1))⊗ FockState(1, FockBasis(1)) ⊗ FockState(0, FockBasis(1)))
# @info express(FockState(1, FockBasis(1))⊗ FockState(0, FockBasis(1)) ⊗ FockState(1, FockBasis(1)))

# S = projector(Z₁) + im*projector(Z₂)
# @info express(S)


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

@resumable function teleport(sim, nodeA::Int, qubitA::RegRef, nodeB::Int, bellpair::Tuple{RegRef,RegRef}, period=1.0)
    @yield  lock(qubitA) & lock(bellpair[1]) & lock(bellpair[2])
    @info "Teleporting qubit $(qubitA.idx) from node $nodeA to node $nodeB"
    tobeteleported = qubitA
    apply!((tobeteleported, bellpair[1]), CNOT)
    apply!(tobeteleported, H)

    zmeas1 = project_traceout!(tobeteleported, σᶻ)
    zmeas2 = project_traceout!(bellpair[1], σᶻ)
    
    if zmeas2==2 apply!(bellpair[2], X) end
    if zmeas1==2 apply!(bellpair[2], Z) end

    unlock(qubitA) 
    unlock(bellpair[1]) 
    unlock(bellpair[2])
    @yield timeout(sim, period)
end

@resumable function entangle(sim, net, client)

    # Set up the entangler protocols at each client
    entangler = EntanglerProt(
        sim=sim, net=net, nodeA=1, slotA=client, nodeB=2, slotB=client,
        success_prob=0.3, rounds=1, attempts=-1, attempt_time=1.0 #pairstate=StabilizerState("XZ ZX") # Note: generate a two-graph state instead of a bell pair
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

@resumable function PiecemakerProt(sim, n, net, graphdata, testgraphdata)

    a = net[1] # switch
    b = net[2] # clients
    past_clients = Int[]

    graph, refstate, core = graphdata
    chosen_core = () 
    core_found = false # flag to check if the core is present

    sanity_counter = 0 # counter to avoid infinite loops. TODO: remove this

    while true
        # Get the successful clients
        activeclients = queryall(b, EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
        if isempty(activeclients)
            @yield timeout(sim, 1.0)
            continue
        end

        # Collect active clients
        current_clients = []
        for c in activeclients
            if c.slot.idx ∉ past_clients
                push!(past_clients, c.slot.idx)
                push!(current_clients, c.slot.idx)
                
                neighbors_client = neighbors(graph, c.slot.idx)
                for neighbor in neighbors_client
                    @yield lock(a[n+c.slot.idx]) & lock(a[n+neighbor])
                    apply!((a[n+c.slot.idx], a[n+neighbor]), ZCZ) 
                    rem_edge!(graph, c.slot.idx, neighbor) # remove the edge from the graph
                    unlock(a[n+c.slot.idx])
                    unlock(a[n+neighbor])
                end
                
            end
        end


        if !core_found
            for core in keys(testgraphdata)
                if Set(core) ⊆ Set(past_clients)
                    @info "Core present, $(core) ⊆ $(past_clients)"
                    chosen_core = core
                    core_found = true
                    @info "Chosen core: ", chosen_core
                    break
                end
            end
        #@info [Set(core) ⊆ Set(past_clients) for core in keys(testgraphdata)]
        else
            # Teleportation protocol: measure out qubits that are entangled and not part of the core
            clients_teleported = []
            for i in current_clients
                if !(i in chosen_core)
                    teleportdone = @process teleport(sim, 1, a[n+i], 2, (a[i], b[i]))
                    push!(clients_teleported, teleportdone)
                end
            end
            if !isempty(clients_teleported)
                @yield reduce(&, clients_teleported)
            end
        
        end
        # If all clients have been entangled teleport the core qubits
        if length(past_clients) == n
            core_teleported = []
            # Teleport the qubits that were not used
            for i in chosen_core
                teleportdone = @process teleport(sim, 1, a[n+i], 2, (a[i], b[i]))
                push!(core_teleported, teleportdone)
            end
            if !isempty(core_teleported)
                @yield reduce(&, core_teleported)
            end
            break
        end
        
        @yield timeout(sim, 1.0) # TODO: this is arbitrary

        sanity_counter += 1 # TODO: remove this
        if sanity_counter > 50
            return
        end
    end
    @info b.stateindices
    @yield reduce(&, [lock(q) for q in b])
    order_state!(b, b.stateindices)

    fidelity = dagger(b.staterefs[2].state[])*refstate
    @info "Fidelity: ", fidelity
    for q in b
        unlock(q)
    end


end

Random.seed!(42)

# Bell state
bell = StabilizerState("ZZ XX")

# Graph state
n = 5

switch = Register(2*n) # storage and communication qubits at the switch
clients = Register(n) # client qubits

ref_register = Register(n) # reference register to store the graph state

net = RegisterNet([switch, clients])
sim = get_time_tracker(net)

# Initialize the switch storage slots in |+⟩ state
initialize!(switch[n+1:2*n], reduce(⊗, fill(X1,n))) 

# Create a simple graph state as reference state
g = Graph(n)
for i in 1:n-1
    add_edge!(g, i, i+1)
end
initialize!(ref_register[1:n], reduce(⊗, fill(X1,n)))  # Initialize a in |+⟩ state
for edge in edges(g)
    u, v = Tuple(edge)
    apply!((ref_register[u],ref_register[v]), ZCZ)  # Create a graph state
end
refstate = ref_register.staterefs[1].state[]
@info "Reference state: ", typeof(refstate)
graphdata = (g, refstate, [2,4])

testgraphdata = Dict{Tuple, Tuple{Graph, Any}}()
operationdata = Dict{Tuple, Any}()
path_to_graph_data = "examples/graphstateswitch/input/7.pickle"
get_graphdata_from_pickle(path_to_graph_data, testgraphdata, operationdata)

# Start entanglement generation for each client
for i in 1:n
    @process entangle(sim, net, i)
end

# Start the piecemaker protocol
@process PiecemakerProt(sim, n, net, graphdata, testgraphdata)

# Run simulation 
run(sim)
