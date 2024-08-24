include("setup.jl")

# Prepare all of the simulation components
n, sim, net, switch_protocol, client_pairs, client_unordered_pairs, consumers, rates, rate_scale = prepare_simulation()

step_ts = range(0, 2, step=0.1)
for t in step_ts
    run(sim, t)
end

# Prepare all of the simulation components
# sim = prepare_simulation_fusion()

# step_ts = range(0, 2, step=0.1)
# for t in step_ts
#     run(sim, t)
# end
