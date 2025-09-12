@testitem "ProtocolZoo Shorthand Constructors" tags=[:protocolzoo_shorthand_constructors] begin
using Revise
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer, CutoffProt
using QuantumSavory.ProtocolZoo.QTCP: EndNodeController, NetworkNodeController, LinkController
using ConcurrentSim

# Create a simple network for testing
net = RegisterNet([Register(3), Register(3), Register(3)])

# Test EntanglerProt shorthand constructor
@test isa(EntanglerProt(net, 1, 2), EntanglerProt)
eprot = EntanglerProt(net, 1, 2; success_prob=0.8, rounds=2)
@test eprot.net === net
@test eprot.nodeA == 1
@test eprot.nodeB == 2
@test eprot.success_prob == 0.8
@test eprot.rounds == 2
@test eprot.sim === get_time_tracker(net)

# Test EntanglementTracker shorthand constructor
@test isa(EntanglementTracker(net, 1), EntanglementTracker)
etracker = EntanglementTracker(net, 2)
@test etracker.net === net
@test etracker.node == 2
@test etracker.sim === get_time_tracker(net)

# Test EntanglementConsumer shorthand constructor (should already exist)
@test isa(EntanglementConsumer(net, 1, 2), EntanglementConsumer)
econsumer = EntanglementConsumer(net, 1, 3; period=0.2)
@test econsumer.net === net
@test econsumer.nodeA == 1
@test econsumer.nodeB == 3
@test econsumer.period == 0.2
@test econsumer.sim === get_time_tracker(net)

# Test SwapperProt shorthand constructor
@test isa(SwapperProt(net, 2), SwapperProt)
swapper = SwapperProt(net, 2; rounds=5, local_busy_time=0.1)
@test swapper.net === net
@test swapper.node == 2
@test swapper.rounds == 5
@test swapper.local_busy_time == 0.1
@test swapper.sim === get_time_tracker(net)

# Test CutoffProt shorthand constructor
@test isa(CutoffProt(net, 1), CutoffProt)
cutoff = CutoffProt(net, 3; period=0.05, retention_time=10.0)
@test cutoff.net === net
@test cutoff.node == 3
@test cutoff.period == 0.05
@test cutoff.retention_time == 10.0
@test cutoff.sim === get_time_tracker(net)

# Test EndNodeController shorthand constructor
@test isa(EndNodeController(net, 1), EndNodeController)
end_controller = EndNodeController(net, 2)
@test end_controller.net === net
@test end_controller.node == 2
@test end_controller.sim === get_time_tracker(net)

# Test NetworkNodeController shorthand constructor
@test isa(NetworkNodeController(net, 1), NetworkNodeController)
net_controller = NetworkNodeController(net, 3)
@test net_controller.net === net
@test net_controller.node == 3
@test net_controller.sim === get_time_tracker(net)

# Test LinkController shorthand constructor
@test isa(LinkController(net, 1, 2), LinkController)
link_controller = LinkController(net, 2, 3)
@test link_controller.net === net
@test link_controller.nodeA == 2
@test link_controller.nodeB == 3
@test link_controller.sim === get_time_tracker(net)

end