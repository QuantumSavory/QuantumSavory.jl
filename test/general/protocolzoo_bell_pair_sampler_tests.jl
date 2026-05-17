using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: BellPairSampler, EntanglerProt, EntanglementCounterpart, EntanglementTracker, SwapperProt
using ConcurrentSim
using ResumableFunctions

@testset "ProtocolZoo BellPairSampler" begin
    @testset "direct link samples Bell stabilizers and fidelity" begin
        net = RegisterNet([Register(3), Register(3)])
        sim = get_time_tracker(net)

        entangler = EntanglerProt(sim, net, 1, 2; rounds=3, success_prob=1.0)
        sampler = BellPairSampler(sim, net, 1, 2; period=nothing, rounds=3)

        @process entangler()
        @process sampler()
        run(sim, 1.0)

        @test length(sampler._log) == 3
        @test all(entry -> entry.zz ≈ 1.0, sampler._log)
        @test all(entry -> entry.xx ≈ 1.0, sampler._log)
        @test all(entry -> entry.yy ≈ -1.0, sampler._log)
        @test all(entry -> entry.fidelity ≈ 1.0, sampler._log)
        @test all(i -> !isassigned(net[1][i]), 1:nsubsystems(net[1]))
        @test all(i -> !isassigned(net[2][i]), 1:nsubsystems(net[2]))
    end

    @testset "sampler can observe repeater-delivered virtual-edge pairs" begin
        net = RegisterNet([Register(4), Register(4), Register(4)]; classical_delay=1e-9)
        sim = get_time_tracker(net)

        @process EntanglerProt(sim, net, 1, 2; rounds=-1, success_prob=1.0, randomize=true, margin=1)()
        @process EntanglerProt(sim, net, 2, 3; rounds=-1, success_prob=1.0, randomize=true, margin=1)()
        @process SwapperProt(sim, net, 2; rounds=-1, nodeL = ==(1), nodeH = ==(3))()
        for node in 1:3
            @process EntanglementTracker(sim, net, node)()
        end

        sampler = BellPairSampler(sim, net, 1, 3; period=0.1, rounds=2)
        @process sampler()
        run(sim, 5.0)

        @test length(sampler._log) >= 1
        @test all(entry -> entry.zz ≈ 1.0, sampler._log)
        @test all(entry -> entry.xx ≈ 1.0, sampler._log)
        @test all(entry -> entry.yy ≈ -1.0, sampler._log)
        @test all(entry -> entry.fidelity ≈ 1.0, sampler._log)
    end

    @testset "sampler waits when no complete pair is available" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)

        sampler = BellPairSampler(sim, net, 1, 2; period=0.2, rounds=1)
        @process sampler()
        run(sim, 0.5)

        @test isempty(sampler._log)
    end

    @testset "sampler waits for reciprocal counterpart metadata" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)

        initialize!((net[1][1], net[2][1]), StabilizerState("ZZ XX"))
        tag!(net[1][1], EntanglementCounterpart, 2, 1)

        sampler = BellPairSampler(sim, net, 1, 2; period=0.2, rounds=1)
        @process sampler()
        run(sim, 0.5)

        @test isempty(sampler._log)
        @test isassigned(net[1][1])
        @test isassigned(net[2][1])
    end

    @testset "event-driven sampler resumes when reciprocal metadata arrives" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)

        initialize!((net[1][1], net[2][1]), StabilizerState("ZZ XX"))
        tag!(net[1][1], EntanglementCounterpart, 2, 1)

        @resumable function add_reciprocal_tag(sim)
            @yield timeout(sim, 0.1)
            tag!(net[2][1], EntanglementCounterpart, 1, 1)
        end

        sampler = BellPairSampler(sim, net, 1, 2; period=nothing, rounds=1)
        @process sampler()
        @process add_reciprocal_tag(sim)
        run(sim, 0.5)

        @test length(sampler._log) == 1
        @test only(sampler._log).fidelity ≈ 1.0
        @test !isassigned(net[1][1])
        @test !isassigned(net[2][1])
    end

    @testset "event-driven sampler waits for first available pair" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)

        @resumable function add_pair(sim)
            @yield timeout(sim, 0.1)
            initialize!((net[1][1], net[2][1]), StabilizerState("ZZ XX"))
            tag!(net[1][1], EntanglementCounterpart, 2, 1)
            tag!(net[2][1], EntanglementCounterpart, 1, 1)
        end

        sampler = BellPairSampler(sim, net, 1, 2; period=nothing, rounds=1)
        @process sampler()
        @process add_pair(sim)
        run(sim, 0.5)

        @test length(sampler._log) == 1
        @test only(sampler._log).fidelity ≈ 1.0
    end

    @testset "sampler unlocks and retries when tags go stale after query" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)

        initialize!((net[1][1], net[2][1]), StabilizerState("ZZ XX"))
        stale_id = tag!(net[1][1], EntanglementCounterpart, 2, 1)
        tag!(net[2][1], EntanglementCounterpart, 1, 1)

        @resumable function delete_tag_while_sampler_waits_for_lock(sim)
            request(net[1][1])
            @yield timeout(sim, 0.1)
            untag!(net[1][1], stale_id)
            unlock(net[1][1])
        end

        sampler = BellPairSampler(sim, net, 1, 2; period=0.2, rounds=1)
        @process delete_tag_while_sampler_waits_for_lock(sim)
        @process sampler()
        run(sim, 0.5)

        @test isempty(sampler._log)
        @test !islocked(net[1][1])
        @test !islocked(net[2][1])
        @test isassigned(net[1][1])
        @test isassigned(net[2][1])
        @test isnothing(query(net[1][1], EntanglementCounterpart, 2, 1))
        @test !isnothing(query(net[2][1], EntanglementCounterpart, 1, 1))
    end
end
