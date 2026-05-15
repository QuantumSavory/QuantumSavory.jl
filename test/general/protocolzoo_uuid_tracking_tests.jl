using Test
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ResumableFunctions

const UUID_PAIR = StabilizerState("ZZ XX")

function fixed_uuid_generator(ids...)
    remaining = collect(ids)
    return () -> popfirst!(remaining)
end

function tag_uuid_pair!(net, node_a, slot_a, node_b, slot_b, uuid)
    initialize!((net[node_a, slot_a], net[node_b, slot_b]), UUID_PAIR)
    tag!(net[node_a, slot_a], EntanglementUUID, uuid, node_b, slot_b)
    tag!(net[node_b, slot_b], EntanglementUUID, uuid, node_a, slot_a)
end

function clear_uuid_tags!(slot, uuid)
    live = query(slot, EntanglementUUID, uuid, ❓, ❓)
    isnothing(live) || untag!(slot, live.id)
    for alias in queryall(slot, EntanglementUUIDAlias, ❓, uuid)
        untag!(slot, alias.id)
    end
end

@resumable function clear_uuid_tags_while_holding(sim, lockslot, clearslot, uuid)
    @yield lock(lockslot)
    @yield timeout(sim, 0.05)
    clear_uuid_tags!(clearslot, uuid)
    unlock(lockslot)
end

@testset "ProtocolZoo - UUID entanglement tracking" begin
    @testset "uuid generator returns positive integer ids" begin
        uuid = generate_pair_uuid()
        @test uuid isa Int
        @test uuid > 0
    end

    @testset "entangler assigns matching UUIDs to both halves" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        entangler = EntanglerProtUUID(net, 1, 2; success_prob=1.0, rounds=1, uuid_generator=fixed_uuid_generator(101))
        @process entangler()
        run(sim, 1.0)

        @test !isnothing(query(net[1, 1], EntanglementUUID, 101, 2, 1))
        @test !isnothing(query(net[2, 1], EntanglementUUID, 101, 1, 1))
        @test observable((net[1, 1], net[2, 1]), Z⊗Z) ≈ 1.0
        @test observable((net[1, 1], net[2, 1]), X⊗X) ≈ 1.0
    end

    @testset "entangler constructor rate and retry branches are stable" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        rated = EntanglerProtUUID(sim, net, 1, 2; rate=10.0, rounds=1)
        @test rated.success_prob == 0.001
        @test rated.attempt_time ≈ 0.0001

        initialize!(net[1, 1], Z1)
        initialize!(net[2, 1], Z1)
        blocked = EntanglerProtUUID(net, 1, 2; retry_lock_time=0.05, rounds=1)
        @process blocked()
        run(sim, 0.12)
        @test isnothing(query(net[1, 1], EntanglementUUID, ❓, 2, ❓))

        net2 = RegisterNet([Register(1), Register(1)])
        failed = EntanglerProtUUID(net2, 1, 2; success_prob=1.0, attempts=0, rounds=1, uselock=false)
        @process failed()
        run(get_time_tracker(net2), 0.1)
        @test !isassigned(net2[1, 1])
        @test !isassigned(net2[2, 1])
    end

    @testset "tracker updates both endpoints after a swap" begin
        net = RegisterNet([Register(1), Register(2), Register(1)]; classical_delay=1e-9)
        sim = get_time_tracker(net)

        tag_uuid_pair!(net, 1, 1, 2, 1, 11)
        tag_uuid_pair!(net, 2, 2, 3, 1, 22)

        for node in vertices(net)
            @process EntanglementTrackerUUID(net, node)()
        end
        swapper = SwapperProtUUID(net, 2; nodeL=1, nodeH=3, rounds=1, uuid_generator=fixed_uuid_generator(33))
        @process swapper()
        run(sim, 1.0)

        @test !isassigned(net[2, 1])
        @test !isassigned(net[2, 2])
        @test !isnothing(query(net[1, 1], EntanglementUUID, 33, 3, 1))
        @test !isnothing(query(net[3, 1], EntanglementUUID, 33, 1, 1))
        @test !isnothing(query(net[1, 1], EntanglementUUIDAlias, 11, 33))
        @test !isnothing(query(net[3, 1], EntanglementUUIDAlias, 22, 33))
        @test observable((net[1, 1], net[3, 1]), Z⊗Z) ≈ 1.0
        @test observable((net[1, 1], net[3, 1]), X⊗X) ≈ 1.0
    end

    @testset "late update routes by UUID instead of reused slot" begin
        net = RegisterNet([Register(1), Register(2), Register(1), Register(1)])
        sim = get_time_tracker(net)

        tag_uuid_pair!(net, 1, 1, 2, 1, 11)
        tag_uuid_pair!(net, 2, 2, 3, 1, 22)

        swapper = SwapperProtUUID(net, 2; nodeL=1, nodeH=3, rounds=1, uuid_generator=fixed_uuid_generator(33))
        @process swapper()
        run(sim, 1.0)

        @test !isnothing(query(net[2, 1], EntanglementUUIDRoute, 11, 3, 1, 22))
        @test !isnothing(query(net[2, 2], EntanglementUUIDRoute, 22, 1, 1, 11))

        tag_uuid_pair!(net, 2, 1, 4, 1, 99)
        put!(messagebuffer(net, 2), Tag(EntanglementUUIDUpdateX, 11, 44, 4, 1, 1))

        @process EntanglementTrackerUUID(net, 2)()
        @process EntanglementTrackerUUID(net, 3)()
        run(sim, 2.0)

        @test !isnothing(query(net[2, 1], EntanglementUUID, 99, 4, 1))
        @test !isnothing(query(net[4, 1], EntanglementUUID, 99, 2, 1))
        @test !isnothing(query(net[3, 1], EntanglementUUID, 44, 4, 1))
        @test !isnothing(query(net[3, 1], EntanglementUUIDAlias, 22, 44))
    end

    @testset "swapper retries and revalidates UUID tags after locking" begin
        empty_net = RegisterNet([Register(1)])
        retrying = SwapperProtUUID(empty_net, 1; retry_lock_time=0.05, rounds=1)
        @process retrying()
        run(get_time_tracker(empty_net), 0.12)
        @test !isassigned(empty_net[1, 1])

        net = RegisterNet([Register(1), Register(2), Register(1)])
        sim = get_time_tracker(net)
        tag_uuid_pair!(net, 1, 1, 2, 1, 11)
        tag_uuid_pair!(net, 2, 2, 3, 1, 22)

        @process clear_uuid_tags_while_holding(sim, net[2, 1], net[2, 1], 11)
        @process SwapperProtUUID(net, 2; nodeL=1, nodeH=3, retry_lock_time=0.05, rounds=1)()
        run(sim, 0.2)

        @test isnothing(query(net[2, 1], EntanglementUUID, 11, 1, 1))
        @test !isnothing(query(net[2, 2], EntanglementUUID, 22, 3, 1))
    end

    @testset "tracker drops stale updates and forwards routed deletes" begin
        stale_net = RegisterNet([Register(1)])
        stale_tracker = EntanglementTrackerUUID(stale_net, 1)
        put!(messagebuffer(stale_net, 1), Tag(EntanglementUUIDUpdateX, 999, 1000, 2, 1, 1))
        put!(messagebuffer(stale_net, 1), Tag(EntanglementUUIDDelete, 998))
        @process stale_tracker()
        @test_logs (:error, r"stale update message") (:error, r"stale delete message") run(get_time_tracker(stale_net), 0.1)
        @test isnothing(query(stale_net[1, 1], EntanglementUUID, 1000, 2, 1))

        routed_net = RegisterNet([Register(1), Register(1)])
        tag!(routed_net[1, 1], EntanglementUUIDRoute, 11, 2, 1, 22)
        put!(messagebuffer(routed_net, 1), Tag(EntanglementUUIDDelete, 11))
        @process EntanglementTrackerUUID(routed_net, 1)()
        run(get_time_tracker(routed_net), 0.1)
        @test !isnothing(querydelete!(messagebuffer(routed_net, 2), EntanglementUUIDDelete, 22))

        locked_net = RegisterNet([Register(1), Register(1)])
        locked_sim = get_time_tracker(locked_net)
        tag_uuid_pair!(locked_net, 1, 1, 2, 1, 33)
        put!(messagebuffer(locked_net, 1), Tag(EntanglementUUIDUpdateX, 33, 44, 2, 1, 1))
        @process clear_uuid_tags_while_holding(locked_sim, locked_net[1, 1], locked_net[1, 1], 33)
        @process EntanglementTrackerUUID(locked_net, 1)()
        @test_logs (:error, r"stale update message") run(locked_sim, 0.2)
        @test isnothing(query(locked_net[1, 1], EntanglementUUID, 44, 2, 1))
    end

    @testset "consumer consumes UUID-tracked end-to-end pairs" begin
        net = RegisterNet([Register(1), Register(2), Register(1)]; classical_delay=1e-9)
        sim = get_time_tracker(net)

        tag_uuid_pair!(net, 1, 1, 2, 1, 11)
        tag_uuid_pair!(net, 2, 2, 3, 1, 22)
        for node in vertices(net)
            @process EntanglementTrackerUUID(net, node)()
        end
        @process SwapperProtUUID(net, 2; nodeL=1, nodeH=3, rounds=1, uuid_generator=fixed_uuid_generator(33))()
        run(sim, 1.0)

        consumer = EntanglementConsumerUUID(net, 1, 3; period=0.1)
        @process consumer()
        run(sim, 2.0)

        @test length(consumer._log) == 1
        @test consumer._log[1].obs1 ≈ 1.0
        @test consumer._log[1].obs2 ≈ 1.0
        @test !isassigned(net[1, 1])
        @test !isassigned(net[3, 1])
    end

    @testset "consumer handles missing or stale counterpart metadata" begin
        missing_net = RegisterNet([Register(1), Register(1)])
        initialize!(missing_net[1, 1], Z1)
        tag!(missing_net[1, 1], EntanglementUUID, 11, 2, 1)
        missing_consumer = EntanglementConsumerUUID(missing_net, 1, 2; period=0.05)
        @process missing_consumer()
        run(get_time_tracker(missing_net), 0.12)
        @test isempty(missing_consumer._log)

        stale_net = RegisterNet([Register(1), Register(1)])
        stale_sim = get_time_tracker(stale_net)
        tag_uuid_pair!(stale_net, 1, 1, 2, 1, 12)
        stale_consumer = EntanglementConsumerUUID(stale_net, 1, 2; period=0.05)
        @process clear_uuid_tags_while_holding(stale_sim, stale_net[2, 1], stale_net[1, 1], 12)
        @process stale_consumer()
        run(stale_sim, 0.2)
        @test isempty(stale_consumer._log)

        split_net = RegisterNet([Register(1), Register(1)])
        initialize!(split_net[1, 1], Z1)
        initialize!(split_net[2, 1], Z1)
        tag!(split_net[1, 1], EntanglementUUID, 13, 2, 1)
        tag!(split_net[2, 1], EntanglementUUID, 13, 1, 1)
        split_consumer = EntanglementConsumerUUID(split_net, 1, 2; period=0.05)
        @process split_consumer()
        run(get_time_tracker(split_net), 0.2)
        @test isempty(split_consumer._log)
        @test !isassigned(split_net[1, 1])
        @test !isassigned(split_net[2, 1])
    end

    @testset "cutoff announces UUID deletion to the remote endpoint" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        tag_uuid_pair!(net, 1, 1, 2, 1, 55)

        @process EntanglementTrackerUUID(net, 2)()
        @process CutoffProtUUID(net, 1; period=0.1, retention_time=0.0)()
        run(sim, 1.0)

        @test !isassigned(net[1, 1])
        @test !isassigned(net[2, 1])
        @test isnothing(query(net[2, 1], EntanglementUUID, 55, 1, 1))
    end
end
