include("setup.jl")

logging = Point2f[] # for plotting
mem_depolar_prob = 0.1 # memory depolarization probability
decoherence_rate = - log(1 - mem_depolar_prob) # decoherence rates
noise_model = Depolarization(1/decoherence_rate) # noise model applied to the memory qubits
link_success_prob = 0.5
rounds = 100 # number of rounds to run

results_per_client = DataFrame[]
for nclients in 2:2
    # Prepare simulation data storage
    distribution_times = Float64[]
    fidelities = Float64[]
    elapsed_times = Float64[]

    sim = prepare_sim(nclients, QuantumOpticsRepr(), noise_model, link_success_prob, 42, rounds)
    elapsed_time = @elapsed run(sim)
end