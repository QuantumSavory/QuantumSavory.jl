include("setup.jl")
using DataFrames
using CSV

results_per_client = DataFrame[]
for nclients in 2:3
    # Prepare simulation components
    type, nruns, n, link_success_prob, mem_depolar_prob, _, _ = prepare_simulation(nclients)  # Assuming `n` is consistent across runs
    distribution_times = Float64[]
    fidelities = Float64[]
    elapsed_times = Float64[]

    for i in 1:nruns
        sim, consumer = prepare_simulation(nclients)[end-1:end]
        elapsed_time = @elapsed run(sim)

        # Extract data from consumer.log
        distribution_time, fidelity = consumer.log[1]
        append!(distribution_times, distribution_time)
        append!(fidelities, fidelity)
        append!(elapsed_times, elapsed_time)
        @info "Run $i completed"
    end

    # Initialize results DataFrame
    results = DataFrame(
        distribution_times = distribution_times,
        fidelities = fidelities,
        elapsed_times = elapsed_times
    )
    results.num_remote_nodes .= n
    results.link_success_prob .= link_success_prob
    results.mem_depolar_prob .= mem_depolar_prob
    results.type .= type

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

# Write results to CSV
# CSV.write("examples/piecemakerswitch/output/piecemaker2-9.csv", results_total)
# CSV.write("examples/piecemakerswitch/output/piecemaker2-9_summary.csv", summary_df)
