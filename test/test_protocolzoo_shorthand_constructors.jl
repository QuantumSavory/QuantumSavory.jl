@testitem "ProtocolZoo Shorthand Constructors" tags=[:protocolzoo_shorthand_constructors] begin
using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer, CutoffProt
using QuantumSavory.ProtocolZoo.QTCP: EndNodeController, NetworkNodeController, LinkController
using ConcurrentSim

# Create a simple network for testing
net = RegisterNet([Register(3), Register(3), Register(3)])

# Test EntanglerProt shorthand constructor
eprot = EntanglerProt(net, 1, 2; success_prob=0.8, rounds=2)
@test eprot.sim === get_time_tracker(net)

# Test EntanglementTracker shorthand constructor
etracker = EntanglementTracker(net, 2)
@test etracker.sim === get_time_tracker(net)

# Test EntanglementConsumer shorthand constructor (should already exist)
econsumer = EntanglementConsumer(net, 1, 3; period=0.2)
@test econsumer.sim === get_time_tracker(net)

# Test SwapperProt shorthand constructor
swapper = SwapperProt(net, 2; rounds=5, local_busy_time=0.1)
@test swapper.sim === get_time_tracker(net)

# Test CutoffProt shorthand constructor
cutoff = CutoffProt(net, 3; period=0.05, retention_time=10.0)
@test cutoff.sim === get_time_tracker(net)

# Test EndNodeController shorthand constructor
end_controller = EndNodeController(net, 2)
@test end_controller.sim === get_time_tracker(net)

# Test NetworkNodeController shorthand constructor
net_controller = NetworkNodeController(net, 3)
@test net_controller.sim === get_time_tracker(net)

# Test LinkController shorthand constructor
link_controller = LinkController(net, 2, 3)
@test link_controller.sim === get_time_tracker(net)

end