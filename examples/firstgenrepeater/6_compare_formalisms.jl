# Include the already implemented code for first gen repeaters in both
# Schroedinger and Clifford formalisms
include("clifford_setup.jl")

using Statistics
#using RecursiveArrayTools
using CairoMakie
CairoMakie.activate!()

##

function monte_carlo_trajectory(;
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
    representation = QuantumOpticsRepr # What representation to use
)

    sim, network = simulation_setup(sizes, T2; representation)

    noisy_pair = stab_noisy_pair_func(F)

    for (;src, dst) in edges(network)
        @process entangler(sim, network, src, dst, noisy_pair, entangler_wait_time, entangler_busy_time)
    end
    for node in vertices(network)
        @process swapper(sim, network, node, swapper_wait_time, swapper_busy_time)
    end
    for nodea in vertices(network)
        for nodeb in vertices(network)
            if nodeb>nodea
                @process purifier(sim, network, nodea, nodeb, purifier_wait_time, purifier_busy_time)
            end
        end
    end

    fidXX = Float64[]
    fidZZ = Float64[]
    registers = [network[node] for node in vertices(network)]
    len = length(registers)

    for t in sampled_times
        run(sim, t)

        fXX = real(observable(registers[[1,len]], [2,2], XX; something=0.0, time=t))
        fZZ = real(observable(registers[[1,len]], [2,2], ZZ; something=0.0, time=t))
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
replicates = 100
sampled_times = 0.:0.2:25.
qo_res = with_logger(nologging) do
    [monte_carlo_trajectory(; sampled_times) for _ in 1:replicates]
end;
qc_res = with_logger(nologging) do
    [monte_carlo_trajectory(; sampled_times, representation=CliffordRepr) for _ in 1:replicates]
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
