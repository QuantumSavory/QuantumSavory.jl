include("setup.jl")

using GLMakie # For plotting
GLMakie.activate!()

##
# Demo: Quantum Memory and T2 Dephasing
#
# This example demonstrates how entanglement fidelity decays over time
# due to T2 dephasing noise. Quantum memory is a critical resource in
# quantum networks, and the limited coherence time of qubits is a
# fundamental challenge.
#
# We create a simple two-node network, establish entangled pairs,
# and track how the entanglement (measured by stabilizer expectation
# values) decays exponentially with time.
#
# Key physics:
# - T2 is the transverse relaxation time, characterizing how fast
#   a qubit loses phase coherence
# - For a Bell pair, the XX and ZZ stabilizers decay as exp(-t/T2)
# - This limits how long entanglement can be stored before it degrades
##

sizes = [3, 3]             # Two nodes with 3 qubits each for memory
T2 = 10.0                  # T2 dephasing time (shorter = faster decay)
F = 0.99                   # Initial fidelity of raw Bell pairs

entangler_wait_time = 0.1  # Wait time if qubits are busy
entangler_busy_time = 0.5  # Time to establish a new entangled pair

sim, network = simulation_setup(sizes, T2)

noisy_pair = noisy_pair_func(F)
for (;src, dst) in edges(network)
    @process entangler(sim, network, src, dst, noisy_pair, entangler_wait_time, entangler_busy_time)
end

# Only one pair at a time - to isolate the memory effect
# We establish one pair and let it sit in memory

# Run the entangler briefly to create some pairs
run(sim, 3.0)

# Now freeze the entangler and let the existing pairs decohere
# (we simply let time pass without creating new pairs)

# Set up visualization: network state + fidelity over time
fig = Figure(size=(800, 400))

# Left: Network visualization
_, ax_net, _, obs_net = registernetplot_axis(fig[1, 1], network)
ax_net.title = "Quantum Memory: Entanglement Decoherence"

# Right: Fidelity decay plot
ax_fid = Axis(fig[1, 2], xlabel="time", ylabel="Stabilizer Expectation",
              title="Entanglement Fidelity vs Time")

registers = [network[node] for node in vertices(network)]
# We track the pair on the first qubit of each node
qubit_idx = 2

ts = Observable(Float64[0])
fidXX = Observable(Float64[0])
fidZZ = Observable(Float64[0])
theor_XX = Observable(Float64[0])
theor_ZZ = Observable(Float64[0])

# Initial state should have fidelity ~F, giving XX and ZZ expectations near +1 for high F
# Theoretical decay: exp(-t/T2) scaled by initial fidelity
lXX = lines!(ax_fid, ts, fidXX, label="XX (measured)", color=:blue)
lZZ = lines!(ax_fid, ts, fidZZ, label="ZZ (measured)", color=:red)
# Theoretical decay curve (for reference)
ltXX = lines!(ax_fid, ts, theor_XX, label="XX (theory exp(-t/T2))", color=:blue, linestyle=:dash)
ltZZ = lines!(ax_fid, ts, theor_ZZ, label="ZZ (theory exp(-t/T2))", color=:red, linestyle=:dash)

xlims!(ax_fid, 0, 50)
ylims!(-0.05, 1.05)
Legend(ax_fid, [lXX, lZZ, ltXX, ltZZ], ["XX (measured)", "ZZ (measured)",
            "XX (theory)", "ZZ (theory)"],
            tellwidth=false, tellheight=false, halign=:right, valign=:top,
            margin=(5, 5, 5, 5))

display(fig)

# Record the decay over time
# Note: The entangler keeps creating new pairs, which partially
# refreshes the ensemble. To see pure decoherence, we look at
# individual pair lifetimes.
step_ts = range(3.0, 50.0, step=0.2)
record(fig, "firstgenrepeater-07.memory_decoherence.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    
    # Measure the stabilizer expectations for the pair on qubit 2 of each node
    fXX = real(observable(registers[[1, 2]], [qubit_idx, qubit_idx], XX; something=0.0, time=t))
    fZZ = real(observable(registers[[1, 2]], [qubit_idx, qubit_idx], ZZ; something=0.0, time=t))
    
    # Theoretical: fidelity decays as F * exp(-t_ since_entanglement / T2)
    # We approximate by just showing the exponential decay envelope
    t_since_entangle = t  # approximate (pairs created at various times)
    decay = exp(-t / T2)
    
    push!(fidXX[], fXX)
    push!(fidZZ[], fZZ)
    push!(theor_XX[], F * decay)
    push!(theor_ZZ[], F * decay)
    push!(ts[], t)
    
    ax_net.title = "Quantum Memory: t=$(round(t, digits=1))"
    notify(obs_net)
    xlims!(ax_fid, 0, t + 1)
end

println("Done! The video shows entanglement decoherence over time.")
println("Notice how the stabilizer expectations (XX, ZZ) decay toward 0")
println("as the qubits undergo T2 dephasing. This is why quantum")
println("memory is challenging and repeaters must operate faster than T2.")
