include("setup.jl")

mem_depolar_prob = 0.1 # memory depolarization probability
decoherence_rate = - log(1 - mem_depolar_prob) # decoherence rates
noise_model = Depolarization(1/decoherence_rate) # noise model applied to the memory qubits
link_success_prob = 0.5
rounds = 100 # number of rounds to run

results_per_client = DataFrame(nclients = Int[], Δt = Float64[], fidelity = Float64[], avg_elapsed_time = Float64[])
for nclients in 2:5
    logging = Tuple[] # for plotting

    # Prepare simulation data storage
    distribution_times = Float64[]
    fidelities = Float64[]
    elapsed_times = Float64[]

    sim = prepare_sim(nclients, QuantumOpticsRepr(), noise_model, link_success_prob, 42, rounds)
    elapsed_time = @elapsed run(sim)

    # Add logging data to DataFrame
    for point in logging
        push!(results_per_client, (nclients = nclients, Δt = point[1], fidelity = point[2], avg_elapsed_time = elapsed_time/rounds))
    end

    @info "Simulation with $(nclients) clients finished in $(elapsed_time) seconds"
end
println(results_per_client)