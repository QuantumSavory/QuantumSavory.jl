include("utils.jl")
##
@resumable function PiecemakerProt(sim, n, net, link_success_prob, logging, rounds)

    while rounds != 0
        @debug "start first round of $(rounds)"
        start = now(sim)

        # Instantiate message buffers for the clients to receive classical correction information
        mbs = [messagebuffer(net[2][i]) for i in 1:n] # messagebuffer is defined always on one register TODO: post issue that this could be better documented

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        # Initialize "piecemaker" qubit in |+> state after first time step has passed, such that if p=1 fidelity=1
        initialize!(net[1][n+1], X1, time=now(sim)+1.0) 

        while true

            # Look for EntanglementCounterpart changed on switch
            counter = 0
            while counter < n # until all clients are entangled
                @yield onchange_tag(net[1])
                counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                if !isnothing(counterpart)
                    slot, _, _ = counterpart
                    @debug counter, counterpart
                    @yield @process fusion(sim, net, net[1][n+1], net[1][slot.idx], period=0.0)
                    @yield @process TeleportTracker(sim, net, 2, mbs[slot.idx]) # TODO: this is ftl, change!
                    counter += 1
                end
            end

            @debug "All clients entangled, measuring piecemaker | time: $(now(sim)-start)"
            @yield lock(net[1][n+1]) & lock(net[2][1])
            zmeas = project_traceout!(net[1][n+1], X)
            if zmeas == 2
                apply!(net[2][1], Z) # apply correction on arbitrary client slot # TODO: this is ftl, change!
            end
            unlock(net[1][n+1])
            unlock(net[2][1])
            break
        end
        @yield reduce(&, [lock(q) for q in net[2]])

        obs = projector(StabilizerState(Stabilizer(ghz(n)))) # GHZ state projector to measure
        result = observable([net[2][i] for i in 1:n], obs; time=now(sim))
        fidelity = sqrt(result'*result)

        while sum(net[2].stateindices) != 0
            @debug net[2].stateindices
            for q in net[2]
                traceout!(q)
            end
        end
        for q in net[2]
            unlock(q)
        end

        # Log outcome
        push!(
            logging,
            (
                now(sim)-start, fidelity
            )
        )
        rounds -= 1
        @debug "Round $(rounds) finished"
    end

end

function prepare_sim(n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, link_success_prob::Float64, seed::Int, logging::DataFrame, rounds::Int)
    
    # Set a random seed
    Random.seed!(seed)
    
    switch = Register(fill(Qubit(), n+1), fill(states_representation, n+1), fill(noise_model, n+1)) # storage qubits at the switch, first qubit is the "piecemaker" qubit
    clients = Register(fill(Qubit(), n),  fill(states_representation, n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, link_success_prob, logging, rounds)
    return sim
end


seed = 42
for n in [2]
    states_representation = QuantumOpticsRepr() 
    mem_depolar_prob = 0.1
    number_of_samples = 10


    df_all_runs = DataFrame()
    for prop in [0.5]#link_success_probs

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )

        decoherence_rate = - log(1 - mem_depolar_prob)
        noise_model = Depolarization(1/decoherence_rate)
        sim = prepare_sim(n, states_representation, noise_model, prop, seed, logging, number_of_samples)
        timed = @elapsed run(sim)

        logging[!, :elapsed_time] .= timed
        logging[!, :number_of_samples] .= number_of_samples
        logging[!, :link_success_prob] .= prop
        logging[!, :mem_depolar_prob] .= mem_depolar_prob
        logging[!, :num_remote_nodes] .= n
        logging[!, :seed] .= seed
        append!(df_all_runs, logging)
        @info "Link success probability: $(prop) | Time: $(timed)"
    end
    @info df_all_runs
    #CSV.write("examples/graphstateswitch/output/piecemaker/qs_piecemaker$(n).csv", df_all_runs)
end
