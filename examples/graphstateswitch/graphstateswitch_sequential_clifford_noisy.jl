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
using DataFrames, StatsPlots
using CSV

include("utils.jl")

@resumable function PiecemakerProt(sim, n, net, graphdata, link_success_prob, logging, rounds)

    a = net[1] # switch
    b = net[2] # clients

    graph = Graph() # general graph object, to be later replaced by chosen state and used for teleportation

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

        # Message buffer for the switch
        mb = messagebuffer(net, 1)
        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        while true
            @yield wait(mb)

            # Get the successful clients
            activeclients = queryall(b, EntanglementCounterpart, ❓, ❓; locked=false, assigned=true) 
            
            if isempty(activeclients)
                @debug "No active clients, waiting for entanglement"
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
                        graph = deepcopy(graphdata[chosen_core][1])
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
        @debug "order teleported: $(order_teleported)"
        order_state!(b, order_teleported)
        
        resultgraph, hadamard_idx, iphase_idx, flips_idx  = graphstate(b.staterefs[1].state[])

        # Compare the graph state with the reference graph state from the input data
        refstate_stabilizers = graphdata[chosen_core][2].staterefs[1].state[]
        coincide = graphstate(refstate_stabilizers)[1] == resultgraph # compare if graphs are equivalent

        # Calculate fidelity
        client_ketstate = Ket(b.staterefs[1].state[]) # get the client state as a ket
        reference_ketstate = Ket(refstate_stabilizers)' # get the reference state as a bra
        fidelity =  abs(reference_ketstate * client_ketstate)^2 # calculate the fidelity of state shared by clients and reference state

        # Calculate the expecation values of stabilizers individually using a helper register
        helperreg = Register(n)
        initialize!(helperreg[1:n], client_ketstate)

        refgraph = graphdata[chosen_core][1]
        exps = map(vertices(refgraph)) do v
            neighs = neighbors(refgraph, v)
            verts = sort([v, neighs...])
            obs = reduce(⊗,[ (i == v) ? σˣ : σᶻ for i in verts ]) # X for the central vertex v, Z for neighbors, Kronecker them together       
            regs = helperreg[sort([v, neighs...])] 
            real(observable(regs, obs; time=now(sim))) # calculate the value of the observable
        end
        
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
                chosen_core, now(sim)-start, coincide, hadamard_idx, iphase_idx, flips_idx, fidelity, exps...
            )
        )
        rounds -= 1
    end
end

function prepare_sim(n, noise_model, graphdata, link_success_prob, seed, logging, rounds)
    
    # Set a random seed
    Random.seed!(seed)
    
    switch = Register(fill(Qubit(), 2*n), fill(CliffordRepr(), 2*n), fill(noise_model, 2*n)) # storage and communication qubits at the switch # fill(T2Dephasing(1.0), 2*n)
    clients = Register(fill(Qubit(), n),  fill(CliffordRepr(), n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start teleportation tracker to correct the client qubits
    @process TeleportTracker(sim, net, 2)

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, graphdata, link_success_prob, logging, rounds)
    return sim
end

rounds = 1000
seed = 42
probs = exp10.(range(-2, stop=-1, length=10))
max_prob = maximum(probs)

for nr in [2]#, 4, 7, 8, 9, 18, 40, 100] # Graph identifier 
    for t in [10.0^i for i in 0:0]
        # Noise model
        noise = Depolarization(t)

        all_runs = DataFrame()
        for link_success_prob in probs
            # Graph state data
            path_to_graph_data = "examples/graphstateswitch/input/$(nr).pickle"
            graphdata, _ = get_graphdata_from_pickle(path_to_graph_data)
            
            ref_core = first(keys(graphdata))
            n = nv(graphdata[ref_core][1]) # number of clients taken from one example graph

            logging = DataFrame(
                chosen_core = Tuple[],
                sim_time    = Float64[],
                coincide    = Float64[],
                H_idx = Any[],
                S_idx = Any[],
                Z_idx = Any[],
                fidelity    = Float64[]
            )
            for i in 1:n
                logging[!, Symbol("eig", i)] = Float64[]
            end

            sim = prepare_sim(n, noise, graphdata, link_success_prob, seed, logging, rounds)
            timed = @elapsed run(sim)

            logging[!, :elapsed_time]       .= timed
            logging[!, :link_success_prob]  .= link_success_prob
            logging[!, :seed]               .= seed
            logging[!, :nqubits]                 .= n
            append!(all_runs, logging)
            @info "Link success probability: $(link_success_prob) | Time: $(timed)"
        end
        @info all_runs
        # CSV.write("examples/graphstateswitch/output/sequential_clifford_noisy_nr$(nr)_$(Symbol(noise))_until$(max_prob).csv", all_runs)
    end
end