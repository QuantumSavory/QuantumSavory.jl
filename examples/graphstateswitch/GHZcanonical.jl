
include("GHZutils.jl")

@resumable function GHZGraphCanonicalProt(sim, n, net, link_success_prob, logging, rounds)

    while rounds != 0
        start = now(sim)

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

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

            # If all clients have established their link-level entanglement teleport GHZ state
            if length(active_clients) == n
                for i in 2:n
                    @yield lock(net[1][i]) & lock(net[1][1]) & lock(net[2][i])
                    apply!((net[1][1], net[1][i]), ZCZ; time=now(sim))
                    ( project_traceout!(net[1][i], σˣ) == 2 ) &&
                    apply!(net[2][i], Z) 
                    
                    unlock(net[1][i]) 
                    unlock(net[1][1]) 
                    unlock(net[2][i])
                end
                @yield lock(net[1][1]) & lock(net[2][1])
                ( project_traceout!(net[1][1], σˣ) == 2 ) && apply!(net[2][1], Z) 
                unlock(net[1][1])
                unlock(net[2][1])
                break
            end
        end
        # Measure the fidelity to the GHZ state
        @yield reduce(&, [lock(q) for q in net[2]])
        obs = projector(Ket(Stabilizer(graphstate(Stabilizer(ghzs[n]))[1]))) # GHZ graphstate projector to measure NOTE: GHZ state is not a graph state, but they are L.C. equivalent
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

    # Create switch and client registers
    switch = Register(fill(Qubit(), n), fill(states_representation, n), fill(noise_model, n)) # storage qubits at the switch, where n qubits are not affected by noise
    clients = Register(fill(Qubit(), n),  fill(states_representation, n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process GHZGraphCanonicalProt(sim, n, net, link_success_prob, logging, rounds)
    return sim
end



seed = 42 # random seed 

for n in 2:8 # number of remote nodes
    states_representation = QuantumOpticsRepr() #CliffordRepr() #
    mem_depolar_prob = 0.1 # depolarization probability of the memory qubits
    number_of_samples = 1000 # number of samples to be taken


    df_all_runs = DataFrame()
    for prop in [0.5] # link success probability

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )

        decoherence_rate = - log(1 - mem_depolar_prob) # decoherence rates
        noise_model = Depolarization(1/decoherence_rate) # noise model applied to the memory qubits
        sim = prepare_sim(n, states_representation, noise_model, prop, seed, logging, number_of_samples)
        timed = @elapsed run(sim)

        # log constants
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
    CSV.write("examples/graphstateswitch/output/GHZsimple/canonical/qs_canonical$(n).csv", df_all_runs)
end