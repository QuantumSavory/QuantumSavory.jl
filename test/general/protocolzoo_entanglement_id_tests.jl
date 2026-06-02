using Test
using ConcurrentSim
using ResumableFunctions
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory,
    EntanglementUpdateX, EntanglementUpdateZ, EntanglementDelete, EntanglementID,
    NO_ENTANGLEMENT_ID, combine_entanglement_ids, fresh_entanglement_id
using QuantumSavory.ProtocolZoo: _combine_entanglement_id_fields, _enforce_history_cap!,
    normalize_entanglement_id

struct CustomEntanglerTag end

@testset "ProtocolZoo entanglement IDs" begin
    @testset "ID accumulator algebra" begin
        a = EntanglementID(11)
        b = EntanglementID(23)
        c = EntanglementID(37)

        @test combine_entanglement_ids(a, b) == combine_entanglement_ids(b, a)
        @test combine_entanglement_ids(a, combine_entanglement_ids(b, c)) ==
            combine_entanglement_ids(combine_entanglement_ids(a, b), c)
        @test combine_entanglement_ids(a, NO_ENTANGLEMENT_ID) == a
        @test combine_entanglement_ids(typemax(EntanglementID), one(EntanglementID)) ==
            NO_ENTANGLEMENT_ID
        @test fresh_entanglement_id() != NO_ENTANGLEMENT_ID
        @test normalize_entanglement_id(-1) == typemax(EntanglementID)
        @test normalize_entanglement_id(NO_ENTANGLEMENT_ID) == NO_ENTANGLEMENT_ID
        @test_throws ArgumentError _combine_entanglement_id_fields("bad", one(EntanglementID))
    end

    @testset "History cap keeps newest FIFO entries" begin
        net = RegisterNet([Register(1)])
        slot = net[1][1]

        for i in 1:5
            tag!(slot, EntanglementHistory, i, i + 10, i + 20, i + 30, i + 40, i, i + 100)
        end

        _enforce_history_cap!(slot, 3)

        histories = queryall(slot, EntanglementHistory, ❓, ❓, ❓, ❓, ❓, ❓, ❓; filo=false)
        @test [history.tag[7] for history in histories] == [3, 4, 5]
        @test SwapperProt(get_time_tracker(net), net, 1; max_history_per_slot=2).max_history_per_slot == 2
        @test SwapperProt(net, 1; max_history_per_slot=2).max_history_per_slot == 2

        _enforce_history_cap!(slot, 0)
        @test isempty(queryall(slot, EntanglementHistory, ❓, ❓, ❓, ❓, ❓, ❓, ❓))
        @test_throws ArgumentError _enforce_history_cap!(slot, -1)
    end

    @testset "EntanglerProt keeps custom tags at legacy arity" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)

        @process EntanglerProt(sim, net, 1, 2; tag=CustomEntanglerTag, success_prob=1.0, rounds=1)()
        run(sim, 1.0)

        tag1 = query(net[1][1], CustomEntanglerTag, 2, 1)
        @test !isnothing(tag1)
        @test length(tag1.tag) == 3
        @test !isnothing(query(net[2][1], CustomEntanglerTag, 1, 1))
    end

    @testset "Duplicate X and Z updates advance pair ID once" begin
        net = RegisterNet([Register(1), Register(1), Register(1)])
        sim = get_time_tracker(net)
        slot = net[1][1]
        target_pair_id = 101
        other_pair_id = 202
        combined_pair_id = combine_entanglement_ids(target_pair_id, other_pair_id)

        initialize!(slot)
        tag!(slot, EntanglementCounterpart, 2, 1, target_pair_id)
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, target_pair_id, other_pair_id, 2, 1, 1, 3, 1, 2))
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateZ, target_pair_id, other_pair_id, 2, 1, 1, 3, 1, 2))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test isnothing(query(slot, EntanglementCounterpart, 2, 1, target_pair_id))
        @test !isnothing(query(slot, EntanglementCounterpart, 3, 1, combined_pair_id))
        @test isempty(messagebuffer(net, 1).buffer)
    end

    @testset "NO_ENTANGLEMENT_ID remains a legacy target ID" begin
        net = RegisterNet([Register(1), Register(1), Register(1)])
        sim = get_time_tracker(net)
        slot = net[1][1]
        other_pair_id = 202

        initialize!(slot)
        tag!(slot, EntanglementCounterpart, 2, 1, NO_ENTANGLEMENT_ID)
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, NO_ENTANGLEMENT_ID, other_pair_id, 2, 1, 1, 3, 1, 1))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test isnothing(query(slot, EntanglementCounterpart, 2, 1, NO_ENTANGLEMENT_ID))
        @test !isnothing(query(slot, EntanglementCounterpart, 3, 1, other_pair_id))
    end

    @testset "NO_ENTANGLEMENT_ID is neutral as other pair ID" begin
        net = RegisterNet([Register(1), Register(1), Register(1)])
        sim = get_time_tracker(net)
        slot = net[1][1]
        target_pair_id = 101

        initialize!(slot)
        tag!(slot, EntanglementCounterpart, 2, 1, target_pair_id)
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, target_pair_id, NO_ENTANGLEMENT_ID, 2, 1, 1, 3, 1, 1))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test isnothing(query(slot, EntanglementCounterpart, 2, 1, target_pair_id))
        @test !isnothing(query(slot, EntanglementCounterpart, 3, 1, target_pair_id))
    end

    @testset "Correction-only update preserves current counterpart identity" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        slot = net[1][1]
        pair_id = 101

        initialize!(slot)
        tag!(slot, EntanglementCounterpart, 2, 1, pair_id)
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, pair_id, NO_ENTANGLEMENT_ID, 2, 1, 1, -1, -1, 1))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test !isnothing(query(slot, EntanglementCounterpart, 2, 1, pair_id))
        @test isempty(messagebuffer(net, 1).buffer)
    end

    @testset "Delayed update does not mutate fresh pair reusing old slot tuple" begin
        net = RegisterNet([Register(1), Register(1), Register(1), Register(1)])
        sim = get_time_tracker(net)
        slot = net[1][1]
        old_pair_id = 101
        old_other_pair_id = 202
        fresh_pair_id = 303
        incoming_other_pair_id = 404

        initialize!(slot)
        tag!(slot, EntanglementHistory, 2, 1, 3, 1, 1, old_pair_id, old_other_pair_id)
        tag!(slot, EntanglementCounterpart, 2, 1, fresh_pair_id)
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, old_pair_id, incoming_other_pair_id, 2, 1, 1, 4, 1, 1))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test !isnothing(query(slot, EntanglementCounterpart, 2, 1, fresh_pair_id))
        @test isnothing(query(slot, EntanglementCounterpart, 4, 1, combine_entanglement_ids(old_pair_id, incoming_other_pair_id)))
        @test !isnothing(query(slot, EntanglementHistory, 4, 1, 3, 1, 1, combine_entanglement_ids(old_pair_id, incoming_other_pair_id), old_other_pair_id))
    end

    @testset "Delete update forwards through history and stores delete marker" begin
        net = RegisterNet([Register(1), Register(1), Register(1), Register(3)]; classical_delay=0.0)
        sim = get_time_tracker(net)
        slot = net[1][1]
        local_chunk_id = 101
        swapped_chunk_id = 202
        forwarded_pair_id = combine_entanglement_ids(local_chunk_id, swapped_chunk_id)

        tag!(slot, EntanglementHistory, 2, 1, 4, 3, 1, local_chunk_id, swapped_chunk_id)
        put!(messagebuffer(net, 1), Tag(EntanglementDelete, local_chunk_id, 2, 1, 1, 1))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test !isnothing(query(messagebuffer(net, 4), EntanglementDelete, forwarded_pair_id, 2, 1, 4, 3))
        @test !isnothing(query(slot, EntanglementDelete, forwarded_pair_id, 1, 1, 4, 3))
        @test isnothing(query(slot, EntanglementHistory, 2, 1, 4, 3, 1, local_chunk_id, swapped_chunk_id))
    end

    @testset "Already advanced history forwards correction-only updates" begin
        net = RegisterNet([Register(1), Register(1), Register(3), Register(1)]; classical_delay=0.0)
        sim = get_time_tracker(net)
        slot = net[1][1]
        target_pair_id = 101
        other_pair_id = 202
        swapped_chunk_id = 303
        updated_local_chunk_id = combine_entanglement_ids(target_pair_id, other_pair_id)
        current_pair_id = combine_entanglement_ids(updated_local_chunk_id, swapped_chunk_id)

        tag!(slot, EntanglementHistory, 4, 1, 3, 3, 1, updated_local_chunk_id, swapped_chunk_id)
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateZ, target_pair_id, other_pair_id, 2, 1, 1, 4, 1, 1))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test !isnothing(query(slot, EntanglementHistory, 4, 1, 3, 3, 1, updated_local_chunk_id, swapped_chunk_id))
        forwarded = query(messagebuffer(net, 3), EntanglementUpdateZ, current_pair_id, NO_ENTANGLEMENT_ID, 4, 1, 3, -1, -1, 1)
        @test !isnothing(forwarded)
    end

    @testset "Update after delete marker advances delete identity" begin
        net = RegisterNet([Register(1), Register(1), Register(1)])
        sim = get_time_tracker(net)
        slot = net[1][1]
        target_pair_id = 101
        other_pair_id = 202
        combined_pair_id = combine_entanglement_ids(target_pair_id, other_pair_id)

        tag!(slot, EntanglementDelete, target_pair_id, 1, 1, 2, 1)
        put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, target_pair_id, other_pair_id, 2, 1, 1, 3, 1, 1))

        @process EntanglementTracker(sim, net, 1)()
        run(sim, 1.0)

        @test isnothing(query(slot, EntanglementDelete, target_pair_id, 1, 1, 2, 1))
        @test !isnothing(query(slot, EntanglementDelete, combined_pair_id, 1, 1, 3, 1))
    end

end
