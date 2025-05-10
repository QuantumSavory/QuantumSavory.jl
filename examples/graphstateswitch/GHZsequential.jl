
include("utils.jl")

@resumable function GHZGraphSequentialProt(sim, n, net, link_success_prob, logging, rounds)

    while rounds != 0
        @debug "start first round of $(rounds)"
        start = now(sim)

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        active_clients = []
        counter_clients = 0
        CZs = []

        while true # until all clients are measured out
            
            if (counter_clients == n) && (length(active_clients) == 1) # measuring out piecemaker slot (first one to arrive) at last
                @yield lock(net[1][active_clients[1]]) & lock(net[2][active_clients[1]])
                ( project_traceout!(net[1][active_clients[1]], σˣ) == 2 ) && apply!(net[2][active_clients[1]], Z) 
                unlock(net[1][active_clients[1]])
                unlock(net[2][active_clients[1]])
                break
            end

            @yield onchange_tag(net[1])
            while true # until the query returns nothing
                counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                if !isnothing(counterpart)
                    slot, _, tag = counterpart
                    push!(active_clients, slot.idx)
                    counter_clients += 1
                else
                    break
                end
            end

            if counter_clients > 1
                while length(active_clients) > 1
                    idx = pop!(active_clients)
                    @yield lock(net[1][idx]) & lock(net[1][active_clients[1]]) & lock(net[2][idx])
                    apply!((net[1][active_clients[1]], net[1][idx]), ZCZ; time=now(sim))
                    push!(CZs, (net[1][active_clients[1]].idx, net[1][idx].idx))
                    ( project_traceout!(net[1][idx], σˣ) == 2 ) && apply!(net[2][idx], Z) 
                    unlock(net[1][idx])
                    unlock(net[1][active_clients[1]])
                    unlock(net[2][idx])
                end
            end
        end

        # Generate GHZ graph state
        graph = Graph() 
        add_vertices!(graph, n)
        for i in 1:n
            if i != active_clients[1]
                add_edge!(graph, (active_clients[1], i))
            end
        end

        # Calculate fidelity
        @yield reduce(&, [lock(q) for q in net[2]])
        obs = projector(StabilizerState(Stabilizer(graph))) #projector(StabilizerState(Stabilizer(graph))) # GHZ graphstate projector to measure NOTE: GHZ state is not a graph state, but it is L.C. equivalent to a graph state

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
    @process GHZGraphSequentialProt(sim, n, net, link_success_prob, logging, rounds)
    return sim
end



seed = 42
for n in [3]
    states_representation = QuantumOpticsRepr()#CliffordRepr()
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
    #CSV.write("examples/graphstateswitch/output/GHZsimple/sequential/qs_sequential$(n).csv", df_all_runs)
end