using CSV, DataFrames, Plots, StatsPlots, Statistics, StatsBase


dfs = DataFrame[]
for nr in [2, 4, 7, 8, 9, 18, 40, 100] # Graph identifier 
    for T2 in [10.0^i for i in 0:3]
        # Read the raw data
        df = CSV.read("examples/graphstateswitch/output/canonical_clifford_noisy_nr$(nr)_T$(T2).csv", DataFrame)
    
        # Count how many columns have eig1, eig2, etc.
        n = count(col -> startswith(col, "eig"), names(df))
    
        # Group and produce mean/sem of each eigᵢ column
        df_stats = combine(
            groupby(df, [:chosen_core, :link_success_prob]),
            [Symbol("eig", i) => mean => Symbol("mean_eig", i) for i in 1:n]..., 
            [Symbol("eig", i) => sem  => Symbol("sem_eig", i)  for i in 1:n]...,
        )
    
        # Now compute a per-row average of all mean_eigᵢ columns
        df_stats[:, :mean_row] = map(eachrow(df_stats)) do row
            # Gather the mean_eig₁, mean_eig₂, … for this row
            vals = [row[Symbol("mean_eig", i)] for i in 1:n]
            mean(vals)
        end
    
        # Compute a per-row mean of all sem_eigᵢ columns
        df_stats[:, :sem_row] = map(eachrow(df_stats)) do row
            vals = [row[Symbol("sem_eig", i)] for i in 1:n]
            mean(vals)
        end
    
        df_stats[!, :nr] .= nr
        df_stats[!, :T2] .= T2
    
        # Drop the individual mean_eigᵢ / sem_eigᵢ columns for concatenation
        for i in 1:n
            select!(df_stats, Not(Symbol("mean_eig", i)))
            select!(df_stats, Not(Symbol("sem_eig", i)))
        end
    
        # Push the result into dfs
        push!(dfs, df_stats)
    end
end
# Concatenate all the dataframes
data = vcat(dfs...)
@info data

## Plotting
t2_values = unique(data.T2)
n_subplots = length(t2_values)

plt = plot(layout = (div(n_subplots,2), 2), size = (1000, 1000))

for (i, t) in enumerate(t2_values)
    # Subset the data for T2 == t
    df_sub = data[data.T2 .== t, :]

    @df df_sub plot!(
        :link_success_prob,
        :mean_row,
        group = :nr,           # color by nr
        subplot = i,           # tell Plots.jl which subplot to draw on
        xlabel = "Link Success Probability",
        ylabel = "Mean Expectation Value",
        title = "T2 = $t",
        legend = :bottomright,
        ylim = (-0.5, 1),
        yerr = :sem_row,
    )
end

display(plt)
savefig(plt, "examples/graphstateswitch/output/stab_expecations_different_T2_all_graphs.pdf")
