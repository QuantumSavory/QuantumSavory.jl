using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, TeleportationProt, EntanglementTracker, EntanglementConsumer, CutoffProt, permits_virtual_edge
using ConcurrentSim

@testset "ProtocolZoo Virtual Edge Detection" begin

# Test default behavior
@test permits_virtual_edge(EntanglerProt(sim=Simulation(), net=RegisterNet([Register(2)]), nodeA=1, nodeB=1)) == false
@test permits_virtual_edge(SwapperProt(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false
@test permits_virtual_edge(EntanglementTracker(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false
@test permits_virtual_edge(CutoffProt(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false

# Test EntanglementConsumer permits virtual edges
@test permits_virtual_edge(EntanglementConsumer(sim=Simulation(), net=RegisterNet([Register(2), Register(2)]), nodeA=1, nodeB=2)) == true
@test permits_virtual_edge(TeleportationProt(sim=Simulation(), net=RegisterNet([Register(2), Register(2)]), sender=1, receiver=2, inputslot=1)) == true

# Test with different constructor variants for EntanglementConsumer
net = RegisterNet([Register(2), Register(2)])
@test permits_virtual_edge(EntanglementConsumer(net, 1, 2)) == true
@test permits_virtual_edge(EntanglementConsumer(get_time_tracker(net), net, 1, 2)) == true
@test permits_virtual_edge(TeleportationProt(net, 1, 2, 1)) == true
@test permits_virtual_edge(TeleportationProt(get_time_tracker(net), net, 1, 2, 1)) == true

end
