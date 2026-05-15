using Test
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo

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

@testset "ProtocolZoo - UUID entanglement tracking" begin
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
