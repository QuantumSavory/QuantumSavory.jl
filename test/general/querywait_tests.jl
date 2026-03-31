using Test
using QuantumSavory
using ResumableFunctions, ConcurrentSim

@testset "Query Wait" begin

@testset "querydelete_wait!" begin
    @resumable function sender(sim, store, putf)
        putf(store, :something)
        @yield timeout(sim, 1.0)
        putf(store, :something)
        @yield timeout(sim, 1.0)
        putf(store, :something)
        @yield timeout(sim, 1.0)
        putf(store, :something)
        @yield timeout(sim, 1.0)
        putf(store, :something)
    end
    @resumable function receiver(sim, store, LOG)
        while true
            qw = querydelete_wait!(store, :something)
            res = @yield qw
            push!(LOG, res)
        end
    end

    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    store, putf = messagebuffer(reg), put!
    LOG = []
    @process receiver(sim, store, LOG)
    @process sender(sim, store, putf)
    @test length(LOG) == 0
    run(sim, 0.1)
    @test length(LOG) == 1
    run(sim, 1.1)
    @test length(LOG) == 2
    run(sim, 2.1)
    @test length(LOG) == 3
    run(sim, 3.1)
    @test length(LOG) == 4
    run(sim, 4.1)
    @test length(LOG) == 5
    run(sim, 5.1)
    @test length(LOG) == 5

    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    store, putf = reg, tag!
    LOG = []
    @process receiver(sim, store, LOG)
    @process sender(sim, store[1], putf)
    @test length(LOG) == 0
    run(sim, 0.1)
    @test length(LOG) == 1
    run(sim, 1.1)
    @test length(LOG) == 2
    run(sim, 2.1)
    @test length(LOG) == 3
    run(sim, 3.1)
    @test length(LOG) == 4
    run(sim, 4.1)
    @test length(LOG) == 5
    run(sim, 5.1)
    @test length(LOG) == 5

end

@testset "query_wait" begin
    @resumable function sender(sim, store, putf)
        @yield timeout(sim, 1.0)
        putf(store, :something)
    end
    @resumable function receiver(sim, store, LOG)
        qw = query_wait(store, :something)
        res = @yield qw
        push!(LOG, res)
    end

    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    store, putf = messagebuffer(reg), put!
    LOG = []
    @process receiver(sim, store, LOG)
    @process sender(sim, store, putf)
    @test length(LOG) == 0
    run(sim, 0.1)
    @test length(LOG) == 0
    run(sim, 1.1)
    @test length(LOG) == 1
    run(sim, 2.1)
    @test length(LOG) == 1

    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    store, putf = reg, tag!
    LOG = []
    @process receiver(sim, store, LOG)
    @process sender(sim, store[1], putf)
    @test length(LOG) == 0
    run(sim, 0.1)
    @test length(LOG) == 0
    run(sim, 1.1)
    @test length(LOG) == 1
    run(sim, 2.1)
    @test length(LOG) == 1

end

@testset "querydelete_wait! on a MessageBuffer returns a buffered match immediately" begin
    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    store = messagebuffer(reg)

    put!(store, Tag(:other))
    put!(store, Tag(:wanted, 42))

    LOG = []

    @resumable function buffered_querydelete_receiver(sim, store, LOG)
        result = @yield querydelete_wait!(store, :wanted, ❓)
        push!(LOG, (now(sim), result))
    end

    @process buffered_querydelete_receiver(sim, store, LOG)
    run(sim)

    @test length(LOG) == 1
    @test LOG[1][1] == 0.0
    @test LOG[1][2].tag == Tag(:wanted, 42)
    @test query(store, :wanted, 42) === nothing
    @test query(store, :other).tag == Tag(:other)
end

@testset "query_wait on a MessageBuffer returns a buffered match immediately" begin
    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    store = messagebuffer(reg)

    put!(store, Tag(:other))
    put!(store, Tag(:wanted, 42))

    LOG = []

    @resumable function buffered_query_receiver(sim, store, LOG)
        result = @yield query_wait(store, :wanted, ❓)
        push!(LOG, (now(sim), result))
    end

    @process buffered_query_receiver(sim, store, LOG)
    run(sim)

    @test length(LOG) == 1
    @test LOG[1][1] == 0.0
    @test LOG[1][2].tag == Tag(:wanted, 42)
    @test query(store, :wanted, 42).tag == Tag(:wanted, 42)
    @test query(store, :other).tag == Tag(:other)
end

@testset "querywait wrapper inference" begin
    reg = Register(1)
    net = RegisterNet([reg])
    mb = messagebuffer(reg)

    proc = @inferred query_wait(reg, :wanted, ❓)
    @test proc isa ConcurrentSim.Process

    proc = @inferred query_wait(mb, :wanted, ❓)
    @test proc isa ConcurrentSim.Process

    proc = @inferred querydelete_wait!(reg, :wanted, ❓)
    @test proc isa ConcurrentSim.Process

    proc = @inferred querydelete_wait!(mb, :wanted, ❓)
    @test proc isa ConcurrentSim.Process
end

end
