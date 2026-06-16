include("f_tmbl.jl")
include("v_tmbl.jl")

using GLMakie
GLMakie.activate!(inline=false)

mc_mean(x) = sum(x) / length(x)
mc_std(x) = sqrt(sum(abs2, x .- mc_mean(x)) / (length(x) - 1))
# Run f while suppressing the per-trial @info reports from the protocols
quietly(f) = Base.CoreLogging.with_logger(f, Base.CoreLogging.NullLogger())

##
# Monte-Carlo trial helpers.
# Each protocol fixes one quantity and lets the other two vary:
# - F-TMBL fixes the generation time window, so we sweep it and record
#   the number of entangled sensors and the GHZ fidelity.
# - V-TMBL fixes the minimum number of entangled sensors μ, so we sweep it
#   and record the preparation time and the GHZ fidelity.
# Classical channels in the network have zero delay, so the corrections are
# applied at the moment of projection and we can measure the fidelity one
# attempt later without accumulating extra idle decoherence.
##

function f_tmbl_trial(S, fixed_time, attempt_time, success_prob, pairstate)
    net = build_sensor_net(S)
    sim = get_time_tracker(net)
    result = Ref(Int[])
    for i in 1:S
        @process EntanglementTracker(sim, net, i)()
    end
    @process f_tmbl(sim, net, S, fixed_time, attempt_time, success_prob, pairstate, result)
    run(sim, fixed_time + attempt_time)
    length(result[]), ghz_fidelity(net, result[])
end

function v_tmbl_trial(S, μ, attempt_time, success_prob, pairstate)
    net = build_sensor_net(S)
    sim = get_time_tracker(net)
    result = Ref(Int[])
    for i in 1:S
        @process EntanglementTracker(sim, net, i)()
    end
    proc = @process v_tmbl(sim, net, S, μ, attempt_time, success_prob, pairstate, result)
    run(sim, proc)  # the process ends at the moment of the GHZ projection
    t_prep = now(sim)
    run(sim, t_prep + attempt_time)  # let the correction messages be applied
    t_prep, length(result[]), ghz_fidelity(net, result[])
end

"""Exact expected number of entangled sensors in F-TMBL: each of the S sensors
succeeds independently within k attempts with probability 1-(1-p)^k."""
f_tmbl_expected_sensors(S, fixed_time, attempt_time, p) =
    S * (1 - (1 - p)^round(Int, fixed_time/attempt_time))

"""P(X ≤ k) for X ~ Binomial(S, q)."""
binomial_cdf(S, q, k) = sum(binomial(S, j) * q^j * (1 - q)^(S - j) for j in 0:k)

"""Exact expected preparation time in V-TMBL: the number of attempts N until the
μ-th sensor succeeds satisfies E[N] = Σₜ P(N > t) = Σₜ P(Bin(S, 1-(1-p)ᵗ) < μ)."""
function v_tmbl_expected_time(S, μ, attempt_time, p)
    total, t = 0.0, 0
    while true
        term = binomial_cdf(S, 1 - (1 - p)^t, μ - 1)
        total += term
        term < 1e-9 && break
        t += 1
    end
    attempt_time * total
end

##
# Sweeps. Fidelities are averaged only over trials where at least one sensor
# was entangled (F-TMBL can end with zero successes).
##

testrun = get(ENV, "QS_TESTRUN", "false") == "true"
N_trials    = testrun ? 3 : 100
fixed_times = testrun ? [0.25] : collect(0.025:0.025:0.5)
μs          = testrun ? [3]    : collect(1:S)

@info "F-TMBL sweep: $(length(fixed_times)) time windows × $N_trials trials"
t_start = time()
f_sensors_mean, f_sensors_std = Float64[], Float64[]
f_fid_mean, f_fid_std = Float64[], Float64[]
for fixed_time in fixed_times
    trials = quietly() do
        [f_tmbl_trial(S, fixed_time, attempt_time, success_prob, noisy_pair) for _ in 1:N_trials]
    end
    ns = first.(trials)
    fids = filter(!isnan, last.(trials))
    push!(f_sensors_mean, mc_mean(ns)); push!(f_sensors_std, mc_std(ns))
    push!(f_fid_mean, mc_mean(fids)); push!(f_fid_std, mc_std(fids))
end
@info "F-TMBL sweep took $(round(time() - t_start, digits=2))s"

@info "V-TMBL sweep: $(length(μs)) values of μ × $N_trials trials"
t_start = time()
v_time_mean, v_time_std = Float64[], Float64[]
v_fid_mean, v_fid_std = Float64[], Float64[]
for μ in μs
    trials = quietly() do
        [v_tmbl_trial(S, μ, attempt_time, success_prob, noisy_pair) for _ in 1:N_trials]
    end
    ts = first.(trials)
    fids = last.(trials)
    push!(v_time_mean, mc_mean(ts)); push!(v_time_std, mc_std(ts))
    push!(v_fid_mean, mc_mean(fids)); push!(v_fid_std, mc_std(fids))
end
@info "V-TMBL sweep took $(round(time() - t_start, digits=2))s"

##
# Plot. One row per protocol: the swept (fixed) quantity on the x axis,
# the two random quantities on the y axes. Error bars are ±1 standard deviation.
##

fig = Figure(size=(900, 600))

ax1 = Axis(fig[1,1],
    xlabel="Time window", ylabel="Entangled sensors",
    title="F-TMBL: GHZ size vs fixed time")
lines!(ax1, fixed_times, f_tmbl_expected_sensors.(S, fixed_times, attempt_time, success_prob),
    label="Theory")
errorbars!(ax1, fixed_times, f_sensors_mean, f_sensors_std)
scatter!(ax1, fixed_times, f_sensors_mean, label="Simulation (N=$N_trials)")
axislegend(ax1, position=:rb)

ax2 = Axis(fig[1,2],
    xlabel="Time window", ylabel="GHZ fidelity",
    title="F-TMBL: fidelity vs fixed time")
errorbars!(ax2, fixed_times, f_fid_mean, f_fid_std)
scatter!(ax2, fixed_times, f_fid_mean)

ax3 = Axis(fig[2,1],
    xlabel="Minimum entangled sensors μ", ylabel="Preparation time",
    title="V-TMBL: prep time vs fixed GHZ size")
lines!(ax3, μs, v_tmbl_expected_time.(S, μs, attempt_time, success_prob),
    label="Theory")
errorbars!(ax3, μs, v_time_mean, v_time_std)
scatter!(ax3, μs, v_time_mean, label="Simulation (N=$N_trials)")
axislegend(ax3, position=:lt)

ax4 = Axis(fig[2,2],
    xlabel="Minimum entangled sensors μ", ylabel="GHZ fidelity",
    title="V-TMBL: fidelity vs fixed GHZ size")
errorbars!(ax4, μs, v_fid_mean, v_fid_std)
scatter!(ax4, μs, v_fid_mean)

save("distributed_ghz_sensors-plots.png", fig)
display(fig)
