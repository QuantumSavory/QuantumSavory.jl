using Test
using Logging
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo:
    EntanglerProt,
    EntanglementCounterpart,
    EntanglementTracker,
    EntanglementUpdateX,
    SwapperProt

@testset "EntanglerProt reports stale counterpart tags" begin
    net = RegisterNet([Register(1), Register(1)])
    sim = get_time_tracker(net)

    tag!(net[1][1], EntanglementCounterpart, 9, 1)
    entangler = EntanglerProt(sim, net, 1, 2;
        success_prob = 1.0,
        attempts = 1,
        attempt_time = 0.0,
        rounds = 1,
    )

    @test_logs (:error, r"EntanglerProt: adding.*already has") min_level=Logging.Error begin
        @process entangler()
        run(sim, 0.1)
    end
end

@testset "EntanglementTracker reports leftover counterpart tags" begin
    net = RegisterNet([Register(1), Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    slot = net[1][1]

    initialize!(slot)
    tag!(slot, EntanglementCounterpart, 2, 1)
    tag!(slot, EntanglementCounterpart, 4, 1)
    put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, 2, 1, 1, 3, 1, 1))

    @test_logs (:error, r"EntanglementTracker: adding.*already has") min_level=Logging.Error begin
        @process EntanglementTracker(sim, net, 1)()
        run(sim, 0.1)
    end
end

@testset "SwapperProt reports same-slot counterpart tags" begin
    net = RegisterNet([Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    slot = net[2][1]

    initialize!(slot)
    tag!(slot, EntanglementCounterpart, 1, 1)
    tag!(slot, EntanglementCounterpart, 3, 1)

    swapper = SwapperProt(sim, net, 2;
        nodeL = <(2),
        nodeH = >(2),
        rounds = 1,
        retry_lock_time = 1.0,
    )

    @test_logs (:error, r"SwapperProt @2: one slot has multiple") min_level=Logging.Error begin
        @process swapper()
        run(sim, 0.1)
    end
    @test !islocked(slot)
end
