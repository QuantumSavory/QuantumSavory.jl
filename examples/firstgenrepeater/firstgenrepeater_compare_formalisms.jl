# Include the already implemented code for first gen repeaters in both
# Schroedinger and Clifford formalisms
include("firstgenrepeater_clifford_setup.jl")

using Statistics
using RecursiveArrayTools
using CairoMakie
CairoMakie.activate!()

##
function monte_carlo_trajectory(
    observable_XX, observable_ZZ, noisy_pair_generator;
    sampled_times = 0.:0.2:25. ,# Times at which we will sample the entanglement fidelity
    sizes = [2,3,4,3,2]        ,# Number of qubits in each register
    T2 = 100.0                 ,# T2 dephasing time of all qubits
    F = 0.97                   ,# Fidelity of the raw Bell pairs
    entangler_wait_time = 0.1  ,# How long to wait if all qubits are busy before retring entangling
    entangler_busy_time = 1.0  ,# How long it takes to establish a newly entangled pair
    swapper_wait_time = 0.1    ,# How long to wait if all qubits are unavailable for swapping
    swapper_busy_time = 0.15   ,# How long it takes to swap two qubits
    purifier_wait_time = 0.15  ,# How long to wait if there are no pairs to be purified
    purifier_busy_time = 0.2   ,# How long the purification circuit takes to execute
)

    sim, mgraph = simulation_setup(sizes, T2)

    for (;src, dst) in edges(mgraph)
        @process entangler(sim, mgraph, src, dst, ()->noisy_pair_generator(F), entangler_wait_time, entangler_busy_time)
    end
    for node in vertices(mgraph)
        @process swapper(sim, mgraph, node, swapper_wait_time, swapper_busy_time)
    end
    for nodea in vertices(mgraph)
        for nodeb in vertices(mgraph)
            if nodeb>nodea
                @process purifier(sim, mgraph, nodea, nodeb, purifier_wait_time, purifier_busy_time)
            end
        end
    end

    fidXX = Float64[]
    fidZZ = Float64[]
    registers = [get_prop(mgraph, node, :register) for node in vertices(mgraph)]
    len = length(registers)

    for t in sampled_times
        run(sim, t)

        fXX = real(observable(registers[[1,len]], [2,2], observable_XX, 0.0; time=t))
        fZZ = real(observable(registers[[1,len]], [2,2], observable_ZZ, 0.0; time=t))
        push!(fidXX,fXX)
        push!(fidZZ,fZZ)
    end

    return fidXX, fidZZ
end

##

# Turn off logging
using Logging
nologging = ConsoleLogger(stderr, Logging.Warn)

# Run sims
replicates = 1000
sampled_times = 0.:0.2:25.
@time qc_res = with_logger(nologging) do
    [monte_carlo_trajectory(qc_XX, qc_ZZ, qc_noisy_pair; sampled_times) for i in 1:replicates]
end;
@time qo_res = with_logger(nologging) do
    [monte_carlo_trajectory(qo_XX, qo_ZZ, qo_noisy_pair; sampled_times) for i in 1:replicates]
end;

# Plot the mean of the observables average over all trajectories
qcx = mean([x for (x,z) in qc_res])
qox = mean([x for (x,z) in qo_res])
qcz = mean([z for (x,z) in qc_res])
qoz = mean([z for (x,z) in qo_res])
fig = Figure()
axx = Axis(fig[1,1][1,1], xlabel="time", ylabel="XX Expectation")
axz = Axis(fig[2,1][1,1], xlabel="time", ylabel="ZZ Expectation")
qcplot = stairs!(axx, sampled_times, qcx)
qoplot = stairs!(axx, sampled_times, qox)
stairs!(axz, sampled_times, qcz)
stairs!(axz, sampled_times, qoz)
Legend(fig[3,1][1,1],[qcplot,qoplot],["Wave function sims","Clifford circuit sims"],
            orientation = :horizontal, tellwidth = false, tellheight = true)
display(fig)
save("firstgenrepeater-09.formalisms.png", fig)
