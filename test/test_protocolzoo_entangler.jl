@testitem "ProtocolZoo Entangler - EntanglerProt" tags=[:protocolzoo_entangler] begin
using Revise
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer
using ConcurrentSim
using ResumableFunctions

net = RegisterNet([Register(5), Register(5)])
sim = get_time_tracker(net)
eprot1 = EntanglerProt(sim, net, 1, 2; chooseA=1, chooseB=5, rounds=1, success_prob=1.)
eprot2 = EntanglerProt(sim, net, 1, 2; chooseA=3, chooseB=3, rounds=1, success_prob=1.)
@process eprot1()
@process eprot2()

run(sim, 3)
@test observable([net[1], net[2]], [1, 5], projector((Z1⊗Z1 + Z2⊗Z2) / sqrt(2))) ≈ 1.0
@test observable([net[1], net[2]], [3, 3], projector((Z1⊗Z1 + Z2⊗Z2) / sqrt(2))) ≈ 1.0

end