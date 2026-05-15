using Test
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ResumableFunctions

const TELEPORTATION_BELL = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0)

function tagged_teleportation_net(input_state; classical_delay=0.0)
    net = RegisterNet([Register(2), Register(1)]; classical_delay)
    initialize!(net[1, 1], input_state)
    initialize!((net[1, 2], net[2, 1]), TELEPORTATION_BELL)
    tag!(net[1, 2], EntanglementCounterpart, 2, 1)
    tag!(net[2, 1], EntanglementCounterpart, 1, 2)
    return net
end

function assert_teleported(input_state; kwargs...)
    net = tagged_teleportation_net(input_state; kwargs...)
    prot = TeleportationProt(net, 1, 2, 1; entangledslot=2, rounds=1)
    @process prot()
    run(get_time_tracker(net), 2.0)

    @test !isassigned(net[1, 1])
    @test !isassigned(net[1, 2])
    @test isassigned(net[2, 1])
    @test observable(net[2, 1], projector(input_state)) ≈ 1.0 atol = 1e-10
    @test isnothing(query(net[2, 1], EntanglementCounterpart, 1, 2))
    @test !isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
end

@resumable function stage_delayed_input_and_pair(sim, net, input_state)
    @yield timeout(sim, 0.15)
    initialize!(net[1, 1], input_state)
    @yield timeout(sim, 0.15)
    initialize!((net[1, 2], net[2, 1]), TELEPORTATION_BELL)
    tag!(net[1, 2], EntanglementCounterpart, 2, 1)
    tag!(net[2, 1], EntanglementCounterpart, 1, 2)
end

@resumable function clear_input_while_output_locked(sim, net)
    outputslot = net[2, 1]
    @yield lock(outputslot)
    @yield timeout(sim, 0.05)
    traceout!(net[1, 1])
    unlock(outputslot)
end

@testset "ProtocolZoo - teleportation protocol" begin
    @testset "teleports Pauli-basis states over a tagged Bell pair" begin
        for input_state in (Z1, Z2, X1, X2)
            assert_teleported(input_state)
        end
    end

    @testset "uses the first suitable Bell-pair tag when no resource slot is specified" begin
        net = tagged_teleportation_net(X1)
        prot = TeleportationProt(net, 1, 2, 1; rounds=1)
        @process prot()
        run(get_time_tracker(net), 2.0)

        @test observable(net[2, 1], projector(X1)) ≈ 1.0 atol = 1e-10
        @test !isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
    end

    @testset "waits for classical correction messages before exposing output" begin
        net = tagged_teleportation_net(Z2; classical_delay=0.5)
        sim = get_time_tracker(net)
        prot = TeleportationProt(net, 1, 2, 1; entangledslot=2, rounds=1)
        @process prot()

        run(sim, 0.25)
        @test isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))

        run(sim, 1.0)
        @test observable(net[2, 1], projector(Z2)) ≈ 1.0 atol = 1e-10
        @test !isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
    end

    @testset "can wait for an entangler to create the Bell pair" begin
        net = RegisterNet([Register(2), Register(1)])
        initialize!(net[1, 1], X2)
        sim = get_time_tracker(net)

        teleport = TeleportationProt(net, 1, 2, 1; retry_lock_time=nothing, rounds=1)
        entangler = EntanglerProt(net, 1, 2; success_prob=1.0, rounds=1, chooseslotA=2, chooseslotB=1)
        @process teleport()
        @process entangler()
        run(sim, 1.0)

        @test observable(net[2, 1], projector(X2)) ≈ 1.0 atol = 1e-10
        @test !isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
    end

    @testset "retries with fixed delays while input or Bell pair are unavailable" begin
        net = RegisterNet([Register(2), Register(1)])
        sim = get_time_tracker(net)
        prot = TeleportationProt(sim, net, 1, 2, 1; entangledslot=2, retry_lock_time=0.1, rounds=1)
        @process prot()
        @process stage_delayed_input_and_pair(sim, net, X1)
        run(sim, 1.0)

        @test observable(net[2, 1], projector(X1)) ≈ 1.0 atol = 1e-10
        @test !isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
    end

    @testset "waits on tag changes when the input is unavailable" begin
        net = RegisterNet([Register(2), Register(1)])
        initialize!((net[1, 2], net[2, 1]), TELEPORTATION_BELL)
        tag!(net[1, 2], EntanglementCounterpart, 2, 1)
        tag!(net[2, 1], EntanglementCounterpart, 1, 2)

        sim = get_time_tracker(net)
        prot = TeleportationProt(sim, net, 1, 2, 1; entangledslot=2, retry_lock_time=nothing, rounds=1)
        @process prot()
        run(sim, 0.1)

        @test !isassigned(net[1, 1])
        @test !isnothing(query(net[1, 2], EntanglementCounterpart, 2, 1))
        @test isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
    end

    @testset "can omit the output metadata tag" begin
        net = tagged_teleportation_net(X2)
        prot = TeleportationProt(net, 1, 2, 1; entangledslot=2, outputtag=nothing, rounds=1)
        @process prot()
        run(get_time_tracker(net), 2.0)

        @test observable(net[2, 1], projector(X2)) ≈ 1.0 atol = 1e-10
        @test isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
    end

    @testset "honors receiver slot filters" begin
        net = RegisterNet([Register(3), Register(2)])
        initialize!(net[1, 1], Z2)
        initialize!((net[1, 2], net[2, 2]), TELEPORTATION_BELL)
        initialize!((net[1, 3], net[2, 1]), TELEPORTATION_BELL)
        tag!(net[1, 2], EntanglementCounterpart, 2, 2)
        tag!(net[2, 2], EntanglementCounterpart, 1, 2)
        tag!(net[1, 3], EntanglementCounterpart, 2, 1)
        tag!(net[2, 1], EntanglementCounterpart, 1, 3)

        prot = TeleportationProt(net, 1, 2, 1; receiver_slot=2, rounds=1)
        @process prot()
        run(get_time_tracker(net), 2.0)

        @test observable(net[2, 2], projector(Z2)) ≈ 1.0 atol = 1e-10
        @test !isnothing(query(net[2, 2], TeleportedState, 1, 1, 2, 2))
        @test !isnothing(query(net[2, 1], EntanglementCounterpart, 1, 3))
    end

    @testset "retries when the input disappears before all locks are acquired" begin
        net = tagged_teleportation_net(Z1)
        sim = get_time_tracker(net)
        prot = TeleportationProt(sim, net, 1, 2, 1; entangledslot=2, retry_lock_time=0.1, rounds=1)
        @process clear_input_while_output_locked(sim, net)
        @process prot()
        run(sim, 0.2)

        @test !isassigned(net[1, 1])
        @test isassigned(net[1, 2])
        @test isassigned(net[2, 1])
        @test isnothing(query(net[2, 1], TeleportedState, 1, 1, 2, 1))
    end

    @testset "rejects using the same input and Bell-pair slot" begin
        net = tagged_teleportation_net(Z1)
        prot = TeleportationProt(net, 1, 2, 1; entangledslot=1, rounds=1)
        @process prot()
        @test_throws ArgumentError run(get_time_tracker(net), 1.0)
    end
end
