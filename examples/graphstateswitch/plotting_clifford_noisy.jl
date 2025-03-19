using CSV, DataFrames, StatsPlots, Statistics, StatsBase

df = CSV.read("examples/graphstateswitch/output/canonical_clifford_noisy.csv", DataFrame)
#

# Group and compute mean & std
n = 6
df_stats = combine(
    groupby(df, [:chosen_core, :link_success_prob]),
    # For each i, produce mean => :mean_eig_i, then std => :std_eig_i
    [Symbol("eig", i) => mean => Symbol("mean_eig", i) for i in 1:n]..., 
    [Symbol("eig", i) => sem  => Symbol("sem_eig", i)  for i in 1:n]...
)

@info df_stats
p = plot()
for i in 1:n
    mean_col = Symbol("mean_eig", i)
    std_col  = Symbol("sem_eig", i)

    # Make a bar plot for this eig
    StatsPlots.@df df_stats plot!(
        :link_success_prob,
        cols(mean_col),
        yerror = cols(std_col),
        label = "eig$(i)"
    )
end
xlabel!("Link Success Probability")
ylabel!("Mean eig ± se")
title!("Stabilizer eigenvalues using T2Dephasing (N=1000)")
display(p)
savefig(p, "examples/graphstateswitch/output/stab_expecations_$(n)users_T2=0.1.pdf")