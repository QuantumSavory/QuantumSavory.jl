"""
Example demonstrating the CutoffProtUUID for automatic qubit deletion.

This shows how to use the cutoff protocol to automatically delete qubits
that exceed a certain age, preventing accumulation of degraded states.
"""

using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProtUUID, CutoffProtUUID, EntanglementTrackerUUID
using ConcurrentSim

# Create network with cutoff protocol
net = RegisterNet([Register(5), Register(5), Register(5)])
sim = get_time_tracker(net)

# Entangle nodes
entangler_1_2 = EntanglerProtUUID(sim, net, 1, 2; rounds=1)
entangler_2_3 = EntanglerProtUUID(sim, net, 2, 3; rounds=1)

@process entangler_1_2()
@process entangler_2_3()
run(sim, 50)

println("Initial entanglement created at time: ", now(sim))

# Add cutoff protocol to delete qubits after 100 time units
cutoff_1 = CutoffProtUUID(sim, net, 1; retention_time=100.0, announce=true)
cutoff_2 = CutoffProtUUID(sim, net, 2; retention_time=100.0, announce=true)
cutoff_3 = CutoffProtUUID(sim, net, 3; retention_time=100.0, announce=true)

# Add trackers to handle deletion messages
tracker_1 = EntanglementTrackerUUID(sim, net, 1)
tracker_2 = EntanglementTrackerUUID(sim, net, 2)
tracker_3 = EntanglementTrackerUUID(sim, net, 3)

@process cutoff_1()
@process cutoff_2()
@process cutoff_3()
@process tracker_1()
@process tracker_2()
@process tracker_3()

println("\nRunning simulation to time 200 (past retention time of 100)...")
run(sim, 200)

println("Simulation complete at time: ", now(sim))
println("Old qubits should have been deleted by cutoff protocol")
