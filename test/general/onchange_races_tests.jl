using Test
using QuantumSavory
using ConcurrentSim
using ResumableFunctions

@resumable function record_wait(sim, event, log, label)
    @yield event
    push!(log, (label, now(sim)))
end

@testset "Change waits release abandoned race branches" begin
    @testset "timeout cleanup precedes the caller's next arrival" begin
        net = RegisterNet([Register(1)])
        sim = get_time_tracker(net)
        mb = messagebuffer(net, 1)
        log = Float64[]

        @resumable function receiver(sim)
            @yield onchange(mb) | timeout(sim, 1)
            # This arrival must queue a notification: cleanup precedes this code.
            put!(mb, Tag(:later))
            @test mb.no_wait[] == 1
            completed = onchange(mb)
            @yield completed
            push!(log, now(sim))
            @yield completed
            push!(log, now(sim))
            @yield onchange(mb)
            push!(log, now(sim))
        end

        @process receiver(sim)
        run(sim, 2)
        @test log == [1.0, 1.0]
        @test mb.no_wait[] == 0
        put!(mb, Tag(:next))
        run(sim, 3)
        @test log == [1.0, 1.0, 2.0]
    end

    @testset "a different buffer wins" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        mbA, mbB = messagebuffer(net, 1), messagebuffer(net, 2)
        log = []
        losing = onchange(mbB)
        @process record_wait(sim, onchange(mbA) | losing, log, :race)
        put!(mbA, Tag(:first))
        run(sim, 1)

        put!(mbB, Tag(:later))
        @test mbB.no_wait[] == 1
        @process record_wait(sim, onchange(mbB), log, :later)
        run(sim, 2)
        @test log == [(:race, 0.0), (:later, 1.0)]
        @test mbB.no_wait[] == 0
        @test_throws ConcurrentSim.EventAbandoned losing | timeout(sim, 1)
    end

    @testset "another subscriber keeps a losing wait registered" begin
        net = RegisterNet([Register(1)])
        sim = get_time_tracker(net)
        mb = messagebuffer(net, 1)
        pending = onchange(mb)
        log = []
        @process record_wait(sim, pending, log, :subscriber)
        @process record_wait(sim, pending | timeout(sim, 1), log, :race)
        run(sim, 2)

        @test log == [(:race, 1.0)]
        @test QuantumSavory.nbwaiters(mb.tag_waiter) == 1
        put!(mb, Tag(:shared))
        run(sim, 3)
        @test log == [(:race, 1.0), (:subscriber, 2.0)]
        @test mb.no_wait[] == 0
        @test pending.generation.waiters == 0
    end

    @testset "nested and duplicate inputs release all registrations" begin
        for combine in (
            (p, q, limit) -> (p | q) | limit,
            (p, q, limit) -> (p & q) | limit,
            (p, q, limit) -> AnyOf(AllOf(p, q), limit),
            (p, q, limit) -> AnyOf(p, p, q, limit),
        )
            net = RegisterNet([Register(1)])
            sim = get_time_tracker(net)
            mb = messagebuffer(net, 1)
            p, q = onchange(mb), onchange(mb)
            @process record_wait(sim, combine(p, q, timeout(sim, 1)), [], :race)
            run(sim, 2)
            @test QuantumSavory.nbwaiters(mb.tag_waiter) == 0
            @test isempty(mb.tag_waiter.current.event.bev.callbacks)
            @test_throws ConcurrentSim.EventAbandoned AllOf(p, timeout(sim, 1))
            put!(mb, Tag(:after_nested_race))
            @test mb.no_wait[] == 1
        end
    end

    @testset "a shared input survives an inner OR timeout" begin
        reg = Register(1)
        sim = get_time_tracker(reg)
        pending = onchange(reg)
        log = []
        @process record_wait(sim, pending & (pending | timeout(sim, 1)), log, :both)
        run(sim, 2)
        @test isempty(log)
        @test QuantumSavory.nbwaiters(reg.tag_waiter[]) == 1
        tag!(reg[1], :later)
        run(sim, 3)
        @test log == [(:both, 2.0)]
        @test pending.generation.waiters == 0
    end

    @testset "repeated timeouts leave no notifier callbacks" begin
        net = RegisterNet([Register(1)])
        sim = get_time_tracker(net)
        mb = messagebuffer(net, 1)

        @resumable function receiver(sim)
            for _ in 1:100
                @yield onchange(mb) | timeout(sim, 1)
                @test QuantumSavory.nbwaiters(mb.tag_waiter) == 0
                @test isempty(mb.tag_waiter.current.event.bev.callbacks)
            end
        end

        proc = @process receiver(sim)
        run(sim, 101)
        @test ConcurrentSim.state(proc) == ConcurrentSim.processed
        put!(mb, Tag(:after_timeouts))
        @test mb.no_wait[] == 1
    end

    @testset "an abandoned scheduled wait never refunds its queued notification" begin
        net = RegisterNet([Register(1)])
        sim = get_time_tracker(net)
        mb = messagebuffer(net, 1)
        put!(mb, Tag(:queued))
        ready = @inferred onchange(mb)
        winner = timeout(sim; priority=1)
        race = ready | winner
        # Explicit priorities put race cleanup before the already scheduled wait.
        ConcurrentSim.step(sim)
        ConcurrentSim.schedule(race; priority=1, value=ConcurrentSim.value(race))
        ConcurrentSim.step(sim)
        @test mb.no_wait[] == 0
        @test_throws ConcurrentSim.EventAbandoned ready | timeout(sim, 1)
        run(sim, 2)
        @test_throws ConcurrentSim.EventAbandoned ready | timeout(sim, 1)

        log = []
        @process record_wait(sim, onchange(mb), log, :fresh)
        run(sim, 3)
        @test isempty(log)
        put!(mb, Tag(:new))
        run(sim, 4)
        @test log == [(:fresh, 3.0)]

        @process record_wait(sim, ready, log, :abandoned)
        @test_throws ConcurrentSim.EventAbandoned run(sim, 5)
    end

    @testset "cleanup affects only the wait's original generation" begin
        net = RegisterNet([Register(1)])
        sim = get_time_tracker(net)
        mb = messagebuffer(net, 1)
        old = onchange(mb)
        old_generation = mb.tag_waiter.current
        race = old | timeout(sim, 1)
        log = []
        @process record_wait(sim, race, log, :race)

        # Schedule the timeout's race, then notify and rotate its generation
        # before the race itself is processed.
        run(sim, 0.5)
        ConcurrentSim.step(sim)
        put!(mb, Tag(:before_cleanup))
        fresh = onchange(mb)
        new_generation = mb.tag_waiter.current
        @test new_generation !== old_generation
        @process record_wait(sim, fresh, log, :fresh)
        run(sim, 2)
        @test old_generation.waiters == 0
        @test new_generation.waiters == 1
        @test log == [(:race, 1.0)]

        put!(mb, Tag(:new_generation))
        run(sim, 3)
        @test log == [(:race, 1.0), (:fresh, 2.0)]
        @test new_generation.waiters == 0
        @test mb.no_wait[] == 0
    end

    @testset "query process wrappers continue after losing a race" begin
        net = RegisterNet([Register(1)])
        sim = get_time_tracker(net)
        mb = messagebuffer(net, 1)
        finding = query_wait(mb, :retained)
        consuming = querydelete_wait!(mb, :consumed)
        @test finding isa ConcurrentSim.Process
        @test consuming isa ConcurrentSim.Process
        @process record_wait(sim, finding | timeout(sim, 1), [], :find)
        @process record_wait(sim, consuming | timeout(sim, 1), [], :consume)
        run(sim, 2)
        put!(mb, Tag(:retained))
        put!(mb, Tag(:consumed))
        run(sim, 3)
        @test ConcurrentSim.state(finding) == ConcurrentSim.processed
        @test ConcurrentSim.state(consuming) == ConcurrentSim.processed
        @test query(mb, :retained).tag == Tag(:retained)
        @test query(mb, :consumed) === nothing
    end
end
