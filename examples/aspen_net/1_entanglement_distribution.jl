using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using Graphs
using Random

Random.seed!(42)

# Sources 1 and 3 send photons to station 2 on a shared slot schedule.
net = RegisterNet(path_graph(3), [Register(1) for _ in 1:3]; classical_delay=0.002)
sim = get_time_tracker(net)
aspen = AspenEntanglerProt(net, 1, 3, 2;
    heralding_prob=0.5, coincidence_prob=0.95, central_fraction=0.1,
    attempt_time=0.001, photon_time=0.003, period=0.02, rounds=40)

# Consume confirmed pairs so the same memories can serve the next slot.
# The target is Psi+, whose ZZ and XX correlations are -1 and +1.
consumer = EntanglementConsumer(net, 1, 3; period=nothing)
@process aspen()
@process consumer()
run(sim, 0.8)

show(stdout, MIME"text/plain"(), aspen)
println()
