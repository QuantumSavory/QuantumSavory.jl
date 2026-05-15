# Headless version — no GLMakie, suitable for CI and benchmarking
include("setup.jl")

chain_length, sim, network = prepare_simulation(
    chain_length=3,
    qubits_per_node=3,
    t2_dephasing=15.0,
    entangler_rate=0.8,
    fidelity_threshold=0.80,
    initial_fidelity=0.95
)

total_time = 20.0
step_size = 0.5
fidelity_log = Float64[]

println("Running adaptive repeater chain simulation (headless)...")
for t in range(0, total_time, step=step_size)
    run(sim, t)
    # Sample end-to-end fidelity
    end_tracker = network[1, :enttrackers]
    fidelities_local = network[1, :fidelities]
    best_fidelity = 0.0
    for (i, et) in enumerate(end_tracker)
        if !isnothing(et) && et.node == chain_length
            best_fidelity = max(best_fidelity, fidelities_local[i])
        end
    end
    push!(fidelity_log, best_fidelity)
end

println("\n=== Results ===")
println("Simulation ran for t=$total_time with step=$step_size")
println("Steps: $(length(fidelity_log))")
println("Max end-to-end fidelity: $(round(maximum(fidelity_log), digits=4))")
println("Avg end-to-end fidelity: $(round(mean(fidelity_log), digits=4))")
println("Final fidelity: $(round(fidelity_log[end], digits=4))")

# Count purification events from fidelity resets
purify_events = count(f -> f < 0.1 && f > 0.0, diff(fidelity_log) .< -0.3)
println("Estimated purification events: $purify_events")
println("\n--- Benchmark summary ---")
println("Total duration: $(total_time) time units")
