include("utils.jl")

@resumable function CanonicalProt(sim, n, net, refstatedata, link_success_prob, logging, rounds)

    a = net[1] # switch
    b = net[2] # clients

    while rounds != 0
        start = now(sim)

        past_clients = Int[]
        order_teleported = Int[]

        sanity_counter = 0 # sanity counter to avoid excessive iterations. TODO: is this necessary?
        
        # Initialize the switch storage slots in |+⟩ state
        initialize!(a[n+1:2*n], reduce(⊗, fill(X1,n))) 

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
                    @yield @process teleport(sim, net, a, b, graph, i, period=0.0)
                    # Start teleportation tracker to correct the client qubits
                    @yield @process TeleportTracker(sim, net, 2, mbs[i])
                    push!(order_teleported, i)
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
        @debug "Ordered indices of teleported storage qubits to the client: $(b.stateindices)"
        @yield reduce(&, [lock(q) for q in b])
        @debug "order teleported: $(order_teleported)"
        order_state!(b, order_teleported)
        
        resultgraph, hadamard_idx, iphase_idx, flips_idx  = graphstate(b.staterefs[1].state[])

        # Compare the graph state with the reference graph state from the input data
        refstate_stabilizers = refstatedata[2].staterefs[1].state[]
        coincide = graphstate(refstate_stabilizers)[1] == resultgraph # compare if graphs are equivalent
        @debug "Graph state coincidence: $(coincide)"

        # Calculate fidelity
        client_ketstate = Ket(b.staterefs[1].state[]) # get the client state as a ket
        reference_ketstate = Ket(refstate_stabilizers)' # get the reference state as a bra
        fidelity =  abs(reference_ketstate * client_ketstate)^2 # calculate the fidelity of state shared by clients and reference state

        # Calculate the expecation values of stabilizers individually using a helper register
        helperreg = Register(n)
        initialize!(helperreg[1:n], client_ketstate)

        refgraph = refstatedata[1]
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
                now(sim)-start, coincide, hadamard_idx, iphase_idx, flips_idx, fidelity, exps...
            )
        )
        rounds -= 1
    end
end

function prepare_sim(n::Int, noise_model::AbstractBackground, refstatedata::Tuple{SimpleGraph{Int64}, Register},
    link_success_prob::Float64, seed::Int, logging::DataFrame, rounds::Int)
    
    # Set a random seed
    Random.seed!(seed)

    qubits = [Qubit() for _ in 1:n]
    bg = [noise_model for _ in 1:n]
    reprs = [CliffordRepr() for _ in 1:n]


    switch = Register([qubits; qubits], [reprs; reprs], [bg; bg]) # storage and communication qubits at the switch
    clients = Register(qubits, reprs, bg) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process CanonicalProt(sim, n, net, refstatedata, link_success_prob, logging, rounds)
    return sim
end