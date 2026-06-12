using Test
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementDelete, _enforce_delete_cap!

@testset "ProtocolZoo Cutoff cleanup contracts" begin
    @testset "Cutoff leaves history metadata alone" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        pair_id = 101

        initialize!((net[1][1], net[2][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
        tag!(net[1][1], EntanglementCounterpart, 2, 1, pair_id)
        tag!(net[2][1], EntanglementCounterpart, 1, 1, pair_id)
        tag!(net[1][1], EntanglementHistory, 9, 8, 7, 6, 5, 111, 222)

        cutoff = CutoffProt(net, 1; retention_time=1.0, period=0.1, announce=false)
        @process cutoff()

        run(sim, 2.0)

        @test !isassigned(net[1][1])
        @test isassigned(net[2][1])
        @test !isempty(queryall(net[2][1], EntanglementCounterpart, 1, 1, pair_id))
        @test isempty(messagebuffer(net, 2).buffer)
        @test !isempty(queryall(net[1][1], EntanglementHistory, 9, 8, 7, 6, 5, 111, 222))

        delete_tags = queryall(net[1][1], EntanglementDelete, ❓, ❓, ❓, ❓, ❓)
        @test Tag(EntanglementDelete, pair_id, 1, 1, 2, 1) in [result.tag for result in delete_tags]
    end

    @testset "Delete cap keeps newest FIFO entries" begin
        net = RegisterNet([Register(2), Register(1)])
        slot = net[1][1]

        for i in 1:5
            tag!(slot, EntanglementDelete, i, 1, 1, 2, i)
        end
        tag!(net[1][2], EntanglementDelete, 100, 1, 2, 2, 1)
        tag!(slot, EntanglementDelete, 200, 3, 1, 2, 1)

        _enforce_delete_cap!(slot, 1, 3)

        delete_tags = queryall(slot, EntanglementDelete, ❓, 1, 1, ❓, ❓; filo=false)
        @test [delete_tag.tag[2] for delete_tag in delete_tags] == [3, 4, 5]
        @test length(queryall(net[1][2], EntanglementDelete, ❓, 1, 2, ❓, ❓)) == 1
        @test length(queryall(slot, EntanglementDelete, ❓, 3, 1, ❓, ❓)) == 1

        @test CutoffProt(get_time_tracker(net), net, 1; max_delete_per_slot=2).max_delete_per_slot == 2
        @test CutoffProt(net, 1; max_delete_per_slot=2).max_delete_per_slot == 2
        @test CutoffProt(net, 1; max_delete_per_slot=nothing).max_delete_per_slot === nothing

        _enforce_delete_cap!(slot, 1, nothing)
        delete_tags = queryall(slot, EntanglementDelete, ❓, 1, 1, ❓, ❓; filo=false)
        @test [delete_tag.tag[2] for delete_tag in delete_tags] == [3, 4, 5]
        @test_throws ArgumentError _enforce_delete_cap!(slot, 1, -1)
    end

    @testset "Delete cap zero keeps no local delete tags" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        pair_id = 303

        initialize!((net[1][1], net[2][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
        tag!(net[1][1], EntanglementCounterpart, 2, 1, pair_id)
        tag!(net[2][1], EntanglementCounterpart, 1, 1, pair_id)
        tag!(net[1][1], EntanglementDelete, 999, 1, 1, 2, 1)

        cutoff = CutoffProt(net, 1; retention_time=1.0, period=0.1, announce=false, max_delete_per_slot=0)
        @process cutoff()

        run(sim, 2.0)

        @test isempty(queryall(net[1][1], EntanglementDelete, ❓, 1, 1, ❓, ❓))
    end
end
