include("GHZutils.jl")

@resumable function FactoryProt(sim, n, net, link_success_prob, logging, rounds)

    while rounds != 0
        @debug "start first round of $(rounds)"
        start = now(sim)

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        # Initialize "piecemaker" qubit in |+> state after first time step has passed, such that if p=1 fidelity=1
        ghz_state = StabilizerState(ghz(n)) # GHZ state locally created
        initialize!(net[1][n+1:2*n], ghz_state, time=now(sim)+1.0) 

        active_clients = []

        while true

            @yield onchange_tag(net[1])
            while true # until the query returns nothing
                counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                if !isnothing(counterpart)
                    slot, _, _ = counterpart
                    push!(active_clients, slot)
                    @debug counterpart
                else
                    break
                end
            end
            @debug "Active clients: ", active_clients

            # If all clients have established their link-level entanglement teleport GHZ state # TODO: this should run on a seperate protocol
            if length(active_clients) == n
                @debug "SIM TIME: $(now(sim)-start)"
                for slot in active_clients
                    i = slot.idx

                    # Start teleportation protocol for each client
                    tobeteleported = net[1][n+i]
                    bellpair = (net[1][i], net[2][i])
                    @yield  lock(tobeteleported) & lock(bellpair[1]) & lock(bellpair[2])
                    
                    # BSM
                    apply!((tobeteleported, bellpair[1]), CNOT; time=now(sim))
                    apply!(tobeteleported, sHadamard)
                
                    zmeas1 = project_traceout!(tobeteleported, σᶻ) 
                    zmeas2 = project_traceout!(bellpair[1], σᶻ) 

                    if zmeas2==2 apply!(bellpair[2], X) end # TODO: instead of doing this 'locally' we should send the correction to the client
                    if zmeas1==2 apply!(bellpair[2], Z) end
                    unlock(tobeteleported)
                    unlock(bellpair[1])
                    unlock(bellpair[2])
                end

                break
            end
        end
        # Measure the fidelity to the GHZ state
        @yield reduce(&, [lock(q) for q in net[2]])
        obs = SProjector(StabilizerState(ghzs[n])) # GHZ state projector to measure
        fidelity = real(observable([net[2][i] for i in 1:n], obs; time=now(sim)))
        foreach(q -> (traceout!(q); unlock(q)), net[2])

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
    
    switch = Register(fill(Qubit(), 2*n), fill(states_representation, 2*n), [fill(noise_model, n)...; fill(nothing, n)...]) # storage qubits at the switch, where n qubits are not affected by noise
    clients = Register(fill(Qubit(), n),  fill(states_representation, n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process FactoryProt(sim, n, net, link_success_prob, logging, rounds)
    return sim
end



seed = parsed_args["seed"] # random seed 
number_of_samples = parsed_args["nsamples"] # number of samples to be taken
states_representation = CliffordRepr()

n = parsed_args["n"] # number of qubits in the GHZ state
    
df_all_runs = DataFrame()
for link_success_prob in exp10.(range(-3, stop=0, length=20))
    timed = 0.0 # time for one run
    for mem_depolar_prob in [0.001, 0.006, 0.078]

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )

        decoherence_rate = - log(1 - mem_depolar_prob) # decoherence rates
        noise_model = Depolarization(1/decoherence_rate) # noise model applied to the memory qubits
        sim = prepare_sim(n, states_representation, noise_model, link_success_prob, seed, logging, number_of_samples)
        timed += @elapsed run(sim)

        # log constants
        logging[!, :elapsed_time] .= timed/number_of_samples
        logging[!, :number_of_samples] .= number_of_samples
        logging[!, :link_success_prob] .= link_success_prob
        logging[!, :mem_depolar_prob] .= mem_depolar_prob
        logging[!, :num_remote_nodes] .= n
        logging[!, :seed] .= seed
        append!(df_all_runs, logging)
    end
    @info "Link success probability: $(link_success_prob) | Time: $(timed)"
end
#@info df_all_runs
CSV.write(parsed_args["output_path"]*"GHZ_factory$(n)_scan.csv", df_all_runs) 