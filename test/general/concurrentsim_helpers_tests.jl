using Test
using Logging
using QuantumSavory
using ConcurrentSim
using ResumableFunctions

@testset "ConcurrentSim helpers" begin
    @testset "@simlog and get_time_tracker expose the active simulation" begin
        regs = [Register(1), Register(1)]
        net = RegisterNet(regs)
        sim = get_time_tracker(net)
        mb = messagebuffer(net[1])

        @test sim === get_time_tracker(regs[1])
        @test sim === get_time_tracker(regs[1][1])
        @test sim === get_time_tracker(mb)

        @resumable function speaker(sim)
            @simlog sim "hello from the simulation"
        end

        out = IOBuffer()
        with_logger(SimpleLogger(out, Logging.Info)) do
            @process speaker(sim)
            run(sim)
        end

        logged = String(take!(out))
        @test occursin("t=0.0000", logged)
        @test occursin("hello from the simulation", logged)
    end

    @testset "RegRef requests proxy the slot lock" begin
        reg = Register(1)
        sim = get_time_tracker(reg)
        state_log = Any[]

        @resumable function locker(sim)
            @yield request(reg[1])
            push!(state_log, (event=:acquired, time=now(sim), locked=islocked(reg[1])))
            @yield timeout(sim, 3.0)
            unlock(reg[1])
            push!(state_log, (event=:released, time=now(sim), locked=islocked(reg[1])))
        end

        @process locker(sim)
        run(sim)

        @test state_log == [
            (event=:acquired, time=0.0, locked=true),
            (event=:released, time=3.0, locked=false),
        ]
    end

    @testset "nongreedymultilock waits for the busy slot and then acquires the full set" begin
        reg = Register(2)
        sim = get_time_tracker(reg)
        acquired_time = Ref(-1.0)
        both_locked = Ref(false)

        @resumable function blocker(sim)
            @yield request(reg[1])
            @yield timeout(sim, 5.0)
            unlock(reg[1])
        end

        @resumable function seeker(sim)
            @yield timeout(sim, 1.0)
            @yield ConcurrentSim.Process(nongreedymultilock, sim, [reg[1], reg[2]])
            acquired_time[] = now(sim)
            both_locked[] = islocked(reg[1]) && islocked(reg[2])
            unlock(reg[1])
            unlock(reg[2])
        end

        @process blocker(sim)
        @process seeker(sim)
        run(sim)

        @test acquired_time[] == 5.0
        @test both_locked[]
    end

    @testset "spinlock retries on a fixed cadence when randomization is disabled" begin
        reg = Register(1)
        sim = get_time_tracker(reg)
        acquired_time = Ref(-1.0)

        @resumable function blocker(sim)
            @yield request(reg[1])
            @yield timeout(sim, 5.0)
            unlock(reg[1])
        end

        @resumable function seeker(sim)
            @yield ConcurrentSim.Process(spinlock, sim, [reg[1]], 2.0; randomize=false)
            acquired_time[] = now(sim)
            unlock(reg[1])
        end

        @process blocker(sim)
        @process seeker(sim)
        run(sim)

        @test acquired_time[] == 6.0
    end
end
