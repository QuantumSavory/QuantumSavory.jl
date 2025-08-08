include("GHZutils.jl")

@resumable function PiecemakerProt(sim, n, net, link_success_prob, logging, rounds)

    while rounds != 0
        @debug "start first round of $(rounds)"
        start = now(sim)

        # Start entanglement generation for each client
        for i in 1:n
            @process entangle(sim, net, i, link_success_prob)
        end

        while true

            # Look for EntanglementCounterpart changed on switch
            counter = 0
            while counter < n # until all clients are entangled
                @yield onchange_tag(net[1])
                if counter == 0 # initialize piecemaker
                    # Initialize "piecemaker" qubit in |+> state when first qubit arrived s.t. if p=1 fidelity=1
                    initialize!(net[1][n+1], X1, time=now(sim))
                end

                while true
                    counterpart = querydelete!(net[1], EntanglementCounterpart, ❓, ❓)
                    if !isnothing(counterpart)
                        slot, _, _ = counterpart

                        # fuse the qubit with the piecemaker qubit
                        @yield lock(net[1][n+1]) & lock(net[1][slot.idx]) & lock(net[2][slot.idx])
                        apply!((net[1][n+1], net[1][slot.idx]), CNOT)
                        ( project_traceout!(net[1][slot.idx], σᶻ) == 2 ) &&
                        apply!(net[2][slot.idx], X)
                        unlock(net[1][n+1])
                        unlock(net[1][slot.idx])
                        unlock(net[2][slot.idx])
                        counter += 1
                        @debug "Fused client $(slot.idx) with piecemaker qubit"
                    else
                        break
                    end
                end
            end

            @debug "All clients entangled, measuring piecemaker | time: $(now(sim)-start)"
            @yield lock(net[1][n+1]) & lock(net[2][1])
            ( project_traceout!(net[1][n+1], σˣ) == 2 ) &&
                apply!(net[2][1], Z) # apply correction on arbitrary client slot # TODO: this is ftl, change!
            unlock(net[1][n+1])
            unlock(net[2][1])
            break
        end

        # Measure the fidelity to the GHZ state
        @yield reduce(&, [lock(q) for q in net[2]])
        obs = SProjector(StabilizerState(ghzs[n])) # GHZ state projector to measure
        fidelity = real(observable([net[2][i] for i in 1:n], obs; time=now(sim)))
        @debug "Fidelity: $(fidelity)"

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
    
    switch = Register(fill(Qubit(), n+1), fill(states_representation, n+1), fill(noise_model, n+1)) # storage qubits at the switch, first qubit is the "piecemaker" qubit
    clients = Register(fill(Qubit(), n),  fill(states_representation, n), fill(noise_model, n)) # client qubits
    net = RegisterNet([switch, clients])
    sim = get_time_tracker(net)

    # Start the piecemaker protocol
    @process PiecemakerProt(sim, n, net, link_success_prob, logging, rounds)
    return sim
end


seed = parsed_args["seed"] # random seed 
number_of_samples = parsed_args["nsamples"] # number of samples to be taken
states_representation = CliffordRepr()

n = parsed_args["n"] # number of qubits in the GHZ state
    
df_all_runs = DataFrame()
for link_success_prob in exp10.(range(-3, stop=0, length=20))
    for mem_depolar_prob in [0.001, 0.006, 0.078]# exp10.(range(-3, stop=0, length=20))

        logging = DataFrame(
            distribution_times  = Float64[],
            fidelities    = Float64[]
        )

        decoherence_rate = - log(1 - mem_depolar_prob) # decoherence rates
        noise_model = Depolarization(1/decoherence_rate) # noise model applied to the memory qubits
        sim = prepare_sim(n, states_representation, noise_model, link_success_prob, seed, logging, number_of_samples)
        timed = @elapsed run(sim)

        # log constants
        logging[!, :elapsed_time] .= timed/number_of_samples
        logging[!, :number_of_samples] .= number_of_samples
        logging[!, :link_success_prob] .= link_success_prob
        logging[!, :mem_depolar_prob] .= mem_depolar_prob
        logging[!, :num_remote_nodes] .= n
        logging[!, :seed] .= seed
        append!(df_all_runs, logging)
    end
end
#@info df_all_runs
CSV.write(parsed_args["output_path"]*"GHZ_piecemaker$(n)_scan.csv", df_all_runs)
