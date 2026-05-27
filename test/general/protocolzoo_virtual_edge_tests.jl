using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer, CutoffProt,
    GHZProjectionProt, GHZReceiverProt, permits_virtual_edge
using ConcurrentSim

@testset "ProtocolZoo Virtual Edge Detection" begin

# Test default behavior
@test permits_virtual_edge(EntanglerProt(sim=Simulation(), net=RegisterNet([Register(2)]), nodeA=1, nodeB=1)) == false
@test permits_virtual_edge(SwapperProt(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false
@test permits_virtual_edge(EntanglementTracker(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false
@test permits_virtual_edge(CutoffProt(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false
@test permits_virtual_edge(GHZReceiverProt(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false

# Test EntanglementConsumer permits virtual edges
@test permits_virtual_edge(EntanglementConsumer(sim=Simulation(), net=RegisterNet([Register(2), Register(2)]), nodeA=1, nodeB=2)) == true
@test permits_virtual_edge(GHZProjectionProt(sim=Simulation(), net=RegisterNet([Register(1), Register(1), Register(2)]), hub=3, members=[1, 2])) == true

# Test with different constructor variants for EntanglementConsumer
net = RegisterNet([Register(2), Register(2)])
@test permits_virtual_edge(EntanglementConsumer(net, 1, 2)) == true
@test permits_virtual_edge(EntanglementConsumer(get_time_tracker(net), net, 1, 2)) == true

end
