include("setup.jl")

results = DataFrame(DistributionTime=Float64[], Fidelity=Float64[])
nruns = 10

# Prepare all of the simulation components
for i in 1:nruns
    n, sim, consumer = prepare_simulation()
    run(sim)

    tuple_result = consumer.log[1]  # Since it's just one tuple

    df_run = DataFrame(consumer.log, [:DistributionTime, :Fidelity])
    append!(results, df_run)
end

@info results