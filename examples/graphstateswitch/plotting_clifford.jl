using CSV, DataFrames, StatsPlots

dfsequential = CSV.read("examples/graphstateswitch/output/canonical_clifford.csv", DataFrame)
dfcanonical  = CSV.read("examples/graphstateswitch/output/canonical.csv", DataFrame)

# Tag each row
dfsequential[!, :name] .= "Canonical"
dfcanonical[!, :name]  .= "Canonical_clifford"

# Append to get a combined DataFrame
df = vcat(dfsequential, dfcanonical)

# Group and compute mean & std
df_stats = combine(
    groupby(df, [:name, :link_success_prob]),
    :sim_time => mean => :mean_time,
    :sim_time => std  => :std_time
)

@info df_stats

plotd = @df df groupedboxplot(
    :link_success_prob,
    :sim_time,
    group   = :name,
    # yerror  = :std_time,    # show std as error bars
    xlabel  = "Link Success Probability",
    ylabel  = "Average Target State Generation Time",
    title   = "Average Generation Time vs. Probability (N=1000)",
    legend  = true,
    marker  = :circle,
    seriestype = :scatter,  # or :line, :scatter, etc.
    #yscale  = :log10,       # log scale for x-axis
)
savefig(plotd, "examples/graphstateswitch/output/canonical_vs_canonical_clifford.pdf")