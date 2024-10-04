include("setup.jl")

# Prepare all of the simulation components
n, sim, consumer = prepare_simulation()

run(sim)

df = DataFrame(consumer.log, [:DistributionTime, :Fidelity, :NaN])
@info df