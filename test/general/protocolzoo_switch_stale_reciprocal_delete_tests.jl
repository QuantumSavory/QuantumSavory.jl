using Test
using Graphs: star_graph
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo

const Switches = QuantumSavory.ProtocolZoo.Switches

@testset "ProtocolZoo Switch stale reciprocal cleanup" begin
    graph = star_graph(3)
    net = RegisterNet(graph, [Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    switch = SimpleSwitchDiscreteProt(net, 1, [2, 3], [1.0, 1.0]; ticktock=1.0, rounds=1)

    initialize!((net[1][1], net[2][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
    tag!(net[1][1], EntanglementCounterpart, 2, 1)
    tag!(net[2][1], EntanglementCounterpart, 1, 1)

    querydelete!(net[2][1], EntanglementCounterpart, 1, 1)
    tag!(net[2][1], EntanglementCounterpart, 3, 1)

    @process Switches._SwitchSynchronizedDelete(switch)()
    run(sim, 1.1)

    @test !isassigned(net[1][1])
    @test isassigned(net[2][1])
    @test isnothing(query(net[1][1], EntanglementCounterpart, 2, 1))
    @test !isnothing(query(net[2][1], EntanglementCounterpart, 3, 1))
end
