include("setup.jl")

# Prepare all of the simulation components
n, sim = prepare_simulation()

step_ts = range(0, 10, step=0.1)
for t in step_ts
    run(sim, t) 
end
