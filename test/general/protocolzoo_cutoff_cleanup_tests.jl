using Test
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementDelete

@testset "ProtocolZoo Cutoff cleanup contracts" begin
    net = RegisterNet([Register(1), Register(1)])
    sim = get_time_tracker(net)

    initialize!((net[1][1], net[2][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
    tag!(net[1][1], EntanglementCounterpart, 2, 1)
    tag!(net[2][1], EntanglementCounterpart, 1, 1)
    tag!(net[1][1], EntanglementHistory, 9, 8, 7, 6, 5)
    tag!(net[1][1], EntanglementDelete, 4, 3, 2, 1)

    cutoff = CutoffProt(net, 1; retention_time=1.0, period=0.1, announce=false)
    @process cutoff()

    run(sim, 2.0)

    @test !isassigned(net[1][1])
    @test isassigned(net[2][1])
    @test !isempty(queryall(net[2][1], EntanglementCounterpart, 1, 1))
    @test isempty(messagebuffer(net, 2).buffer)
    @test isempty(queryall(net[1][1], EntanglementHistory, ❓, ❓, ❓, ❓, ❓))

    delete_tags = queryall(net[1][1], EntanglementDelete, ❓, ❓, ❓, ❓)
    @test Tag(EntanglementDelete, 1, 1, 2, 1) in [result.tag for result in delete_tags]
end
