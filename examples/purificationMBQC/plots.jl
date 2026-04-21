include("full_purification_example.jl")

using GLMakie # For plotting
GLMakie.activate!(inline=false)

##
# Sweep input fidelity, collecting success probability and output fidelity
##

N_trials = 10
input_fidelities = collect(0.5:0.05:1.0)

success_probs_theory = Float64[]
success_probs_empirical = Float64[]
output_fidelities_empirical = Float64[]

t_start = time()
for F in input_fidelities
    p_bloch = (4F - 1) / 3
    P_accept_theory = (1 + 3*p_bloch^4) / 4
    push!(success_probs_theory, P_accept_theory)

    n_success = 0
    total_fidelity = 0.0
    for _ in 1:N_trials
        pairstate_noisy = noisy_pair_func(perfect_pair, F)
        regs = [Register(2) for _ in 1:2*(n+k)]
        net = RegisterNet(regs)
        sim = get_time_tracker(net)
        @process run_purification(sim, net, n, resource_state, alice_nodes, bob_nodes,
            communication_slot, storage_slot, pairstate_noisy, H1, H2, logxs, logzs, rounds=1)
        run(sim, 5.0)
        tags = [query(net[alice_nodes[n+i]][storage_slot], PurifiedEntanglementCounterpart, ❓, ❓) for i in 1:k]
        if all(!isnothing, tags)
            n_success += 1
            fids = [real(observable([net[alice_nodes[n+i]], net[bob_nodes[n+i]]], [storage_slot, storage_slot], projector(perfect_pair))) for i in 1:k]
            total_fidelity += sum(fids)
        end
    end

    push!(success_probs_empirical, n_success / N_trials)
    push!(output_fidelities_empirical, n_success > 0 ? total_fidelity / (n_success * k) : NaN)
end
@info "Sweep completed in $(round(time() - t_start, digits=2))s"

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
