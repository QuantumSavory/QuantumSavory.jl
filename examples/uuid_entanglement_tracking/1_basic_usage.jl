"""
Basic usage example of UUID-based entanglement tracking.

This demonstrates creating a simple 4-node linear network and performing
entanglement swaps using the UUID-based protocols.
"""

using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim

# Create a linear network of 4 nodes
net = RegisterNet([Register(3), Register(3), Register(3), Register(3)])
sim = get_time_tracker(net)

# Create entanglers between neighboring nodes (rounds=1 means one entanglement per pair)
entangler_1_2 = EntanglerProtUUID(sim, net, 1, 2; rounds=1)
entangler_2_3 = EntanglerProtUUID(sim, net, 2, 3; rounds=1)
entangler_3_4 = EntanglerProtUUID(sim, net, 3, 4; rounds=1)

@process entangler_1_2()
@process entangler_2_3()
@process entangler_3_4()

# Run simulation to create entanglement
run(sim, 50)

println("After initial entanglement creation:")
println("  Time: ", now(sim))

# Create swappers that will perform entanglement swaps
swapper_2 = SwapperProtUUID(sim, net, 2; nodeL=<(2), nodeH=>(2), rounds=-1)
swapper_3 = SwapperProtUUID(sim, net, 3; nodeL=<(3), nodeH=>(3), rounds=-1)

# Create trackers to handle swap notifications
tracker_1 = EntanglementTrackerUUID(sim, net, 1)
tracker_2 = EntanglementTrackerUUID(sim, net, 2)
tracker_3 = EntanglementTrackerUUID(sim, net, 3)
tracker_4 = EntanglementTrackerUUID(sim, net, 4)

@process swapper_2()
@process swapper_3()
@process tracker_1()
@process tracker_2()
@process tracker_3()
@process tracker_4()

# Run the full simulation
run(sim, 1000)

println("\nAfter swapping:")
println("  Time: ", now(sim))
println("  Swaps performed - nodes 1 and 4 should now be entangled")
