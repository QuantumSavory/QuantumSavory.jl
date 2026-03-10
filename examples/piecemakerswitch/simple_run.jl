include("setup.jl")
using CSV
using GLMakie
logging = Point2f[] # TODO: just put this here to avoid error, find better way to share with setup.jl

# mem_depolar_prob = 0.1 # memory depolarization probability
# decoherence_rate = - log(1 - mem_depolar_prob) # decoherence rates
noise_model = T2Dephasing(9.49122) # λ=0.9 #Depolarization(1/decoherence_rate) # noise model applied to the memory qubits
link_success_prob = 0.6
rounds = 10000 # number of rounds to run

results_per_client = DataFrame(nclients = Int[], Δt = Float64[], fidelity = Float64[])
for nclients in [5, 10, 15, 20, 25, 30, 35]
    logging = Tuple[] # for plotting

    # Prepare simulation data storage
    distribution_times = Float64[]
    fidelities = Float64[]
    elapsed_times = Float64[]

    sim = prepare_sim(nclients, CliffordRepr(), noise_model, link_success_prob, 42, rounds)
    elapsed_time = @elapsed run(sim)

    # Add logging data to DataFrame
    for point in logging
        push!(results_per_client, (nclients = nclients, Δt = point[1], fidelity = point[2]))
    end

    @info "Simulation with $(nclients) clients finished in $(elapsed_time) seconds"
end
CSV.write("results_piecemaker.csv", results_per_client)

## calculate statistics (mean, std and standard error) from results_per_client
using Statistics
se(x) = std(x) / sqrt(length(x))  # Standard error helper function
grouped = groupby(results_per_client, :nclients)
stats = combine(grouped, :Δt => mean => :mean_Δt,
                        :Δt => std => :std_Δt,
                        :Δt => se  => :se_Δt,
                        :fidelity => mean => :mean_fidelity,
                        :fidelity => std => :std_fidelity,
                        :fidelity => se => :se_fidelity)
CSV.write("stats_piecemaker.csv", stats)