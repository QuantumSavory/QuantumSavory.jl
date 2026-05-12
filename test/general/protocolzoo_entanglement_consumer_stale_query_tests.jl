using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglementConsumer, EntanglementCounterpart
using QuantumSavory.StatesZoo: DepolarizedBellPair
using ConcurrentSim
using ResumableFunctions

@testset "ProtocolZoo EntanglementConsumer stale query" begin
    net = RegisterNet([Register(1), Register(1)])
    sim = get_time_tracker(net)

    initialize!((net[1][1], net[2][1]), DepolarizedBellPair(1.0))
    stale_id = tag!(net[1][1], EntanglementCounterpart, 2, 1)
    tag!(net[2][1], EntanglementCounterpart, 1, 1)

    consumer = EntanglementConsumer(sim, net, 1, 2; period=1.0)

    @resumable function delete_stale_tag(sim, slot, id)
        untag!(slot, id)
        @yield timeout(sim, 1.0)
    end

    @process consumer()
    @process delete_stale_tag(sim, net[1][1], stale_id)

    run(sim, 0.5)

    @test !islocked(net[1][1])
    @test !islocked(net[2][1])
    @test isempty(consumer._log)
    @test query(net[2][1], EntanglementCounterpart, 1, 1) !== nothing
end
