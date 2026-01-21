"""
Example demonstrating the EntanglementConsumerUUID protocol.

This shows how to consume entangled pairs for measurements and applications.
"""

using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim

# Create a simple two-node system with consumer
net = RegisterNet([Register(3), Register(3)])
sim = get_time_tracker(net)

entangler = EntanglerProtUUID(sim, net, 1, 2; rounds=-1)
consumer = EntanglementConsumerUUID(sim, net, 1, 2; period=10.0)

@process entangler()
@process consumer()
run(sim, 1000)

# Access the consumption log
println("Entanglement Consumption Summary")
println("=" ^ 50)
println("Total consumption events: ", length(consumer._log))
println("\nFirst 10 measurements:")
for (i, (t, obs1, obs2)) in enumerate(consumer._log[1:min(10, end)])
    println("  Event $i - Time: $t, Z⊗Z: $obs1, X⊗X: $obs2")
end
