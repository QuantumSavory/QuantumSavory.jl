include("full_purification_example.jl")

using GLMakie
GLMakie.activate!(inline=false)

##
# Plot
##

fig = Figure(size=(900, 400))

ax1 = Axis(fig[1,1],
    xlabel="Input Fidelity F", ylabel="Success Probability",
    title="Purification Success Probability")
lines!(ax1, input_fidelities, success_probs_theory, label="Theory")
scatter!(ax1, input_fidelities, success_probs_empirical, label="Empirical (N=$(N_trials))")
axislegend(ax1, position=:lt)

ax2 = Axis(fig[1,2],
    xlabel="Input Fidelity F", ylabel="Output Fidelity",
    title="Purification Output Fidelity")
lines!(ax2, [input_fidelities[1], input_fidelities[end]], [input_fidelities[1], input_fidelities[end]],
    linestyle=:dash, color=:gray, label="No improvement")
scatter!(ax2, input_fidelities, output_fidelities_empirical, label="Empirical (N=$(N_trials))")
axislegend(ax2, position=:lt)

display(fig)
save("purificationMBQC-plots.png", fig)
