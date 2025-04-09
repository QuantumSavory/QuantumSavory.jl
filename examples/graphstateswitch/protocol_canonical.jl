include("utils.jl")

@resumable function CanonicalProt(sim, n, net, refstatedata, link_success_prob, logging, rounds)

    a = net[1] # switch
    b = net[2] # clients

    while rounds != 0
        start = now(sim)

        past_clients = Int[]
        sanity_counter = 0 # sanity counter to avoid excessive iterations. TODO: is this necessary?

        # Message buffer for the switch
        mb = messagebuffer(net, 1)

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        while true
            # Copy reference graph to be modified during teleportation
            graph = copy(refstatedata[1]) 

            # Look for EntanglementCounterpart message sent to switch
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
                end
            end
            @debug "Active clients: $(past_clients)"

            # If all clients have been entangled teleport the qubits
            if length(past_clients) == n
                @debug "SIM TIME: $(now(sim)-start)"
                @debug "All clients entangled, teleporting qubits"
                
                # Instantiate message buffers for the clients (to receive classical correction information)
                mbs = [messagebuffer(net[2][i]) for i in past_clients]
                for i in past_clients
                    # Start teleportation protocol for each client
                    @yield @process projective_teleport(sim, net, a, b, graph, i, period=0.0)
                    # Start teleportation tracker to correct the client qubits
                    @yield @process TeleportTracker(sim, net, 2, mbs[i])
                end
                #@yield reduce(&, correction_jobs) # wait for all teleportation trackers to finish
                @debug "SIM TIME AFTER TELEPORT: $(now(sim)-start)"
                # Start teleportation tracker to correct the client qubits
                break
            end

            sanity_counter += 1 # TODO: make this prettier?
            if sanity_counter > 10000
                @info "Link success probability might be too small, maximum iterations reached. Terminate."
                return
            end
        end

        @yield reduce(&, [lock(q) for q in b])

        current_order = copy(b.stateindices) # order in which state indices are stored
        order_state!(b.staterefs[1].state[], current_order)
        
        resultgraph, hadamard_idx, iphase_idx, flips_idx  = graphstate(b.staterefs[1].state[])

        coincide, hadamard_idx, iphase_idx, flips_idx, fidelity = get_performance_metrics(sim, b, refstatedata)

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
                now(sim)-start, coincide, hadamard_idx, iphase_idx, flips_idx, fidelity#, exps...
            )
        )
        rounds -= 1
    end
end

function prepare_sim(n::Int, noise_model::Union{AbstractBackground, Nothing}, refstatedata::Tuple{SimpleGraph{Int64}, Register},
    link_success_prob::Float64, seed::Int, logging::DataFrame, rounds::Int)
    
    # Set a random seed
    Random.seed!(seed)

    switch = Register([Qubit() for _ in 1:n], [CliffordRepr() for _ in 1:n], [noise_model for _ in 1:n]) # storage and communication qubits at the switch
    clients = Register([Qubit() for _ in 1:n], [CliffordRepr() for _ in 1:n], [noise_model for _ in 1:n]) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process CanonicalProt(sim, n, net, refstatedata, link_success_prob, logging, rounds)
    return sim
end

## test 
# n = 4
# g = random_regular_graph(n, 2, seed=42)
# refstate = Stabilizer(g)   
# refregister = Register(fill(Qubit(), n), fill(CliffordRepr(), n)) # storage and communication qubits at the switch
# initialize!(refregister[1:n], StabilizerState(refstate))
# refstatedata = (g, refregister)

# sim = prepare_sim(n, nothing, refstatedata, 0.5, 42, DataFrame(), 100)
# run(sim)