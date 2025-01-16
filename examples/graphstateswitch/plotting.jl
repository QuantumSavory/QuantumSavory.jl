using CSV
using DataFrames, StatsPlots

# Suppose your data is in a DataFrame named `df`
# Columns: :chosen_core, :link_success_prob, :sim_time, :fidelity, :seed, :elapsed_time

df = CSV.read("examples/graphstateswitch/output/sequential.csv", DataFrame)

# Suppose your raw data is in a DataFrame named df
# columns: :chosen_core, :link_success_prob, :sim_time, etc.

# Convert chosen_core to something groupable if needed (string or keep tuple).
# Convert link_success_prob to something groupable if it's float, that’s okay.

df[!, :core_str] = string.(df[!, :chosen_core])

df_stats = combine(
    groupby(df, [:core_str, :link_success_prob]),
    :sim_time => mean => :mean_time,
    :sim_time => std  => :std_time
)

@df df_stats plot(
    :link_success_prob,
    :mean_time,
    #group   = :core_str,    # one line per core
    yerror  = :std_time,    # show std as error bars
    xlabel  = "Link Success Probability",
    ylabel  = "Mean Simulation Time",
    title   = "Mean Sim Time vs. Probability (±1σ)",
    legend  = :topright,
    marker  = :circle,
    seriestype = :scatter,  # or :line, :scatter, etc.
    yscale  = :log10,       # log scale for x-axis
)

