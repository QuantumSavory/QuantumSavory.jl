
include("utils.jl")
##
@resumable function GHZGraphCanonicalProt(sim, n, net, link_success_prob, logging, rounds)

    while rounds != 0
        @debug "start first round of $(rounds)"
        start = now(sim)

        # Instantiate message buffers for the clients to receive classical correction information
        mbs = [messagebuffer(net[2][i]) for i in 1:n]

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        graph = graphstate(Stabilizer(ghz(n)))[1]

        active_clients = []

        while true

            @yield onchange_tag(net[1])
            while true # until the query returns nothing
                counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                if !isnothing(counterpart)
                    slot, _, tag = counterpart
                    push!(active_clients, slot)
                    @debug counterpart
                else
                    break
                end
            end
            @debug "Active clients: ", active_clients

            # If all clients have established their link-level entanglement teleport GHZ state
            if length(active_clients) == n
                for i in 2:n
                    apply!((net[1][1], net[1][i]), ZCZ; time=now(sim))
                end
                for i in 1:n
                    zmeas = project_traceout!(net[1][i], σˣ) 
                    if zmeas==2 apply!(net[2][i], Z) end
                end
                break
                # @debug "SIM TIME: $(now(sim)-start)"
                # for slot in active_clients
                #     i = slot.idx
                #     # Start teleportation protocol for each client
                #     @yield @process projective_teleport(sim, net, net[1], net[2], graph, i, period=0.0)
                #     # Start teleportation tracker to correct the client qubits
                #     @yield @process TeleportTracker(sim, net, 2, mbs[i])
                # end

                # break
            end
        end
        @yield reduce(&, [lock(q) for q in net[2]])

        obs = projector(StabilizerState(Stabilizer(graphstate(Stabilizer(ghz(n)))[1]))) # GHZ graphstate projector to measure NOTE: GHZ state is not a graph state, but it is L.C. equivalent to a graph state
        result = observable([net[2][i] for i in 1:n], obs; time=now(sim))
        fidelity = sqrt(result'*result)


        for q in net[2]
            traceout!(q)
        end
        @debug net[2].stateindices
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
        @info "Round $(rounds) finished"
    end

end

function prepare_sim(n::Int, states_representation::AbstractRepresentation, noise_model::Union{AbstractBackground, Nothing}, link_success_prob::Float64, seed::Int, logging::DataFrame, rounds::Int)
    
    # Set a random seed
    Random.seed!(seed)
    
    switch = Register(fill(Qubit(), n), fill(states_representation, n), fill(noise_model, n)) # storage qubits at the switch, where n qubits are not affected by noise
    clients = Register(fill(Qubit(), n),  fill(states_representation, n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process GHZGraphCanonicalProt(sim, n, net, link_success_prob, logging, rounds)
    return sim
end



seed = 42
for n in [7]
    states_representation = QuantumOpticsRepr() #CliffordRepr() #
    mem_depolar_prob = 0.1
    number_of_samples = 1000


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
    #@info df_all_runs
    CSV.write("examples/graphstateswitch/output/factory/qs_canonical$(n)_adapted.csv", df_all_runs)
end