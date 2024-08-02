@testitem "ProtocolZoo Throws - SimpleSwitchDiscreteProt" tags=[:protocolzoo_throws] begin
    using Revise
    using ResumableFunctions
    using ConcurrentSim
    using QuantumSavory.ProtocolZoo
    using Graphs

    net = RegisterNet([Register(2), Register(3), Register(4)])
    @test_throws "`clientnodes` must be unique" SimpleSwitchDiscreteProt(net, 1, [2,2,3], fill(0.5, 3))
    @test_throws "`clientnodes` must be directly connected to the `switchnode`" SimpleSwitchDiscreteProt(net, 1, 2:4, fill(0.5, 3))
    @test_throws "`ticktock` must be positive" SimpleSwitchDiscreteProt(net, 1, [2], fill(0.5, 1); ticktock=0)
    @test_throws "`rounds` must be positive or" SimpleSwitchDiscreteProt(net, 1, [2], fill(0.5, 1); rounds=0)
    @test_throws "`success_probs` must have the same length as `clientnodes`" SimpleSwitchDiscreteProt(net, 1, [2], fill(0.5, 3))
    @test_throws "`success_probs` must be in the range [0,1]" SimpleSwitchDiscreteProt(net, 1, [2], fill(-0.5, 1))
    @test_throws "`success_probs` must be in the range [0,1]" SimpleSwitchDiscreteProt(net, 1, [2], fill(1.5, 1))
end
