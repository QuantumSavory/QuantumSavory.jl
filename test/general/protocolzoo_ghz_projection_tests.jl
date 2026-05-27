using Test
using ConcurrentSim
using ResumableFunctions
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, GHZMember
using QuantumClifford: ghz

@resumable function delayed_ghz_entanglers(sim, net, members, hub, delay)
    @yield timeout(sim, delay)
    for member in members
        entangler = EntanglerProt(
            sim,
            net,
            member,
            hub;
            pairstate=StabilizerState("XX ZZ"),
            chooseslotA=1,
            chooseslotB=member,
            rounds=1,
            success_prob=1.0,
        )
        @process entangler()
    end
end

function start_ghz_receivers!(sim, net, members)
    receivers = GHZReceiverProt[]
    for member in members
        tracker = EntanglementTracker(sim, net, member)
        receiver = GHZReceiverProt(sim, net, member; rounds=1)
        @process tracker()
        @process receiver()
        push!(receivers, receiver)
    end
    return receivers
end

function assert_delivered_ghz(net, members, hub; ghz_id=1)
    member_count = length(members)
    for (member_index, member) in enumerate(members)
        @test !isnothing(query(net[member][1], GHZMember, ghz_id, hub, member_index, member_count; assigned=true))
        @test isnothing(query(net[member][1], EntanglementCounterpart, hub, member))
    end
    ghz_state = StabilizerState(ghz(member_count))
    @test observable([net[member][1] for member in members], projector(ghz_state)) ≈ 1.0
end

@testset "ProtocolZoo GHZ projection protocol" begin
    @test_throws ArgumentError GHZProjectionProt(Simulation(), RegisterNet([Register(1), Register(1)]), 1, [2])
    @test_throws ArgumentError GHZProjectionProt(Simulation(), RegisterNet([Register(1), Register(1), Register(1)]), 1, [1, 2])
    @test_throws ArgumentError GHZProjectionProt(Simulation(), RegisterNet([Register(1), Register(1), Register(1)]), 1, [2, 2])

    @testset "direct hub projection delivers a tagged GHZ state" begin
        members = [1, 2, 3]
        hub = 4
        net = RegisterNet([[Register(1) for _ in members]; Register(length(members))])
        sim = get_time_tracker(net)

        receivers = start_ghz_receivers!(sim, net, members)

        for member in members
            entangler = EntanglerProt(
                sim,
                net,
                member,
                hub;
                pairstate=StabilizerState("XX ZZ"),
                chooseslotA=1,
                chooseslotB=member,
                rounds=1,
                success_prob=1.0,
            )
            @process entangler()
        end

        projector = GHZProjectionProt(sim, net, hub, members; rounds=1, retry_lock_time=nothing)
        @process projector()
        run(sim, 10)

        @test length(projector._log) == 1
        @test projector._log[1].member_nodes == members
        @test projector._log[1].member_slots == fill(1, length(members))
        @test all(receiver -> length(receiver._log) == 1, receivers)
        assert_delivered_ghz(net, members, hub)

        html = sprint(show, MIME"text/html"(), projector)
        @test occursin("GHZProjectionProt", html)
        @test occursin("Delivered GHZ states", html)
    end

    @testset "event-driven waiting starts only after all input pairs arrive" begin
        members = [1, 2, 3]
        hub = 4
        net = RegisterNet([[Register(1) for _ in members]; Register(length(members))])
        sim = get_time_tracker(net)

        start_ghz_receivers!(sim, net, members)
        projector = GHZProjectionProt(sim, net, hub, members; rounds=1, retry_lock_time=nothing)
        @process projector()
        @process delayed_ghz_entanglers(sim, net, members, hub, 5.0)

        run(sim, 10)

        @test length(projector._log) == 1
        @test projector._log[1].t > 5.0
        assert_delivered_ghz(net, members, hub)
    end
end
