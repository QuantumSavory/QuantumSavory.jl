include("setup.jl")

# A honest channel: the sifted key must be error free
sim, net, stats_pristine = prepare_simulation(intercept_prob=0.0, rounds=500, seed=42)
run(sim)
qber_pristine = qber(stats_pristine)

# An intercept-resend eavesdropper on every pulse: QBER should approach 25%
sim_eve, net_eve, stats_eve = prepare_simulation(intercept_prob=1.0, rounds=2000, seed=7)
run(sim_eve)
qber_eve = qber(stats_eve)

@info "BB84 single runs" qber_pristine stats_pristine.sifted qber_eve stats_eve.sifted
