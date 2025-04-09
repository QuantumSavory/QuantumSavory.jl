include("utils.jl")

@resumable function PiecemakerProt(sim, n, net, graphdata, link_success_prob, logging, rounds)

    a = net[1] # switch
    b = net[2] # clients

    graph = Graph() # general graph object, to be later replaced by chosen state

    while rounds != 0
        start = now(sim)

        past_clients = Int[]
        current_clients = Int[]
        order_teleported = Int[]

        chosen_core = () 
        core_found = false # flag to signal if the core is present

        sanity_counter = 0 # counter to avoid infinite loops. TODO: is this necessary?

        # Setup message buffers
        mb = messagebuffer(net, 1)
        mbs_clients = [messagebuffer(net[2][i]) for i in 1:n]
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
            @debug "Active clients: ", current_clients

            if !core_found
                for core in keys(graphdata)
                    if Set(core) ⊆ Set(past_clients)
                        @debug "Core present, $(core) ⊆ $(past_clients)"
                        chosen_core = core
                        core_found = true
                        @debug "Chosen core: ", chosen_core
                        graph = deepcopy(graphdata[chosen_core][1])
                        @debug graph
                        break # core is found no need for further checking
                    end
                end
            else
                @debug "Chosen core: ", chosen_core
                # Teleportation protocol: apply CZ gates according to graph and measure out qubits that are entangled and not part of the core
                for i in current_clients
                    if !(i in chosen_core)
                        @yield @process projective_teleport(sim, net, a, b, graph, i, period=0.0)
                        @yield @process TeleportTracker(sim, net, 2, mbs_clients[i])
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
                    @yield @process projective_teleport(sim, net, a, b, graph, i, period=0.0)
                    @yield @process TeleportTracker(sim, net, 2, mbs_clients[i])
                    push!(order_teleported, i)
                end
                break
            end

            sanity_counter += 1 # TODO: make this prettier?
            if sanity_counter > 10000
                @info "Link success probability might be too small, maximum iterations encountered. Terminate."
                return
            end
        end

        @yield reduce(&, [lock(q) for q in b])
        current_order = copy(b.stateindices)
        order_state!(b.staterefs[1].state[], current_order)

        coincide, hadamard_idx, iphase_idx, flips_idx, fidelity = get_performance_metrics(sim, b, graphdata[chosen_core])
        
        while sum(b.stateindices) != 0
            @debug b.stateindices
            for q in b
                traceout!(q)
            end
        end
        for q in b
            unlock(q)
        end

        # Log outcome
        push!(
            logging,
            (
                now(sim)-start, coincide, hadamard_idx, iphase_idx, flips_idx, fidelity, chosen_core
            )
        )
        rounds -= 1
    end
end

function prepare_sim(n::Int, noise_model::Union{AbstractBackground, Nothing}, graphdata::Dict{Tuple, Tuple{SimpleGraph, Any}}, link_success_prob::Float64, seed::Int, logging::DataFrame, rounds::Int)
    
    # Set a random seed
    Random.seed!(seed)
    
    switch = Register(fill(Qubit(), n), fill(CliffordRepr(), n), fill(noise_model, n)) # storage qubits at the switch
    clients = Register(fill(Qubit(), n),  fill(CliffordRepr(), n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, graphdata, link_success_prob, logging, rounds)
    return sim
end