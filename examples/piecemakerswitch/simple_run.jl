include("setup.jl")
using DataFrames
using CSV

# Set up the simulation parameters
name = "qs_piecemeal"

nruns = 10
mem_depolar_prob = 0.1
link_success_prob = 0.5

results_per_client = DataFrame[]
for nclients in 2:2
    # Prepare simulation data storage
    distribution_times = Float64[]
    fidelities = Float64[]
    elapsed_times = Float64[]

    # Run the simulation nruns times
    for i in 1:nruns
        sim, consumer = prepare_simulation(nclients, mem_depolar_prob, link_success_prob)
        elapsed_time = @elapsed run(sim) 
        # Extract data from consumer.log
        distribution_time, fidelity = consumer.log[1]
        append!(distribution_times, distribution_time)
        append!(fidelities, fidelity)
        append!(elapsed_times, elapsed_time)
        @info "Run $i completed"
    end

    # Fill the results DataFrame
    results = DataFrame(
        distribution_times = distribution_times,
        fidelities = fidelities,
        elapsed_times = elapsed_times
    )
    results.num_remote_nodes .= nclients
    results.link_success_prob .= link_success_prob
    results.mem_depolar_prob .= mem_depolar_prob
    results.type .= name

    push!(results_per_client, results)
    @info "Clients $nclients completed"
end
results_total = vcat(results_per_client...)

# Group and summarize the data
grouped_df = groupby(results_total, [:num_remote_nodes, :distribution_times])
summary_df = combine(
    grouped_df,
    :fidelities => mean => :mean_fidelities,
    :fidelities => std => :std_fidelities
)

@info summary_df

# Uncomment to write results to CSV
# CSV.write("examples/piecemakerswitch/output/piecemaker-eventdriven.csv", results_total)
# CSV.write("examples/piecemakerswitch/output/piecemaker-eventdriven_summary.csv", summary_df)