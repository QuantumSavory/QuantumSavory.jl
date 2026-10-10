include("setup.jl")

using CairoMakie

# Sweep the eavesdropper's intercept probability and compare the measured QBER
# with the theoretical intercept-resend value of p/4.
intercept_probs = collect(0.0:0.1:1.0)
mean_qbers = Float64[]
key_lengths = Int[]
for p in intercept_probs
    sim, net, stats = prepare_simulation(intercept_prob=p, rounds=1000, seed=11)
    run(sim)
    push!(mean_qbers, qber(stats))
    push!(key_lengths, stats.sifted)
end

theory = collect(0.0:0.01:1.0)

fig = Figure(size=(1200, 500))
ax_qber = Axis(fig[1, 1], xlabel="intercept probability", ylabel="QBER",
    title="BB84 intercept-resend eavesdropping")
lines!(ax_qber, theory, theory ./ 4, linestyle=:dash, color=:gray, label="theory p/4")
scatter!(ax_qber, intercept_probs, mean_qbers, label="simulated")
lines!(ax_qber, intercept_probs, mean_qbers, color=:blue)
axislegend(ax_qber)

ax_key = Axis(fig[1, 2], xlabel="intercept probability", ylabel="sifted key length")
barplot!(ax_key, intercept_probs, key_lengths, color=:blue)

if get(ENV, "QS_TESTRUN", "false") != "true"
    save("bb84qkd_sweep.png", fig)
end
fig
