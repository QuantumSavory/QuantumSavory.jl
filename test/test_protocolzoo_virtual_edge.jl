@testitem "ProtocolZoo Virtual Edge Detection" tags=[:protocolzoo_virtual_edge] begin
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer, CutoffProt, permits_virtual_edge
using ConcurrentSim

# Test default behavior
@test permits_virtual_edge(EntanglerProt(sim=Simulation(), net=RegisterNet([Register(2)]), nodeA=1, nodeB=1)) == false
@test permits_virtual_edge(SwapperProt(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false
@test permits_virtual_edge(EntanglementTracker(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false
@test permits_virtual_edge(CutoffProt(sim=Simulation(), net=RegisterNet([Register(2)]), node=1)) == false

# Test EntanglementConsumer permits virtual edges
@test permits_virtual_edge(EntanglementConsumer(sim=Simulation(), net=RegisterNet([Register(2), Register(2)]), nodeA=1, nodeB=2)) == true

# Test with different constructor variants for EntanglementConsumer
net = RegisterNet([Register(2), Register(2)])
@test permits_virtual_edge(EntanglementConsumer(net, 1, 2)) == true
@test permits_virtual_edge(EntanglementConsumer(get_time_tracker(net), net, 1, 2)) == true

end