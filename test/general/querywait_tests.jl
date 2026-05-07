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

@testset "query_wait on a Register is non-consuming for simultaneous waiters" begin
    @resumable function shared_tag_sender(sim, reg)
        @yield timeout(sim, 1.0)
        tag!(reg[1], :shared, 1)
    end
    @resumable function shared_tag_query_receiver(sim, reg, LOG, receiver_id)
        result = @yield query_wait(reg, :shared, ❓)
        push!(LOG, (receiver_id, result))
    end

    reg = Register(1)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    LOG = []

    @process shared_tag_query_receiver(sim, reg, LOG, 1)
    @process shared_tag_query_receiver(sim, reg, LOG, 2)
    @process shared_tag_sender(sim, reg)
    run(sim, 1.1)

    @test length(LOG) == 2
    @test LOG[1][2].id == LOG[2][2].id
    @test query(reg, :shared, 1) !== nothing
end

@testset "querydelete_wait! on a Register consumes one tag per waiter" begin
    @resumable function two_tag_sender(sim, reg)
        @yield timeout(sim, 1.0)
        tag!(reg[1], :consume, 1)
        @yield timeout(sim, 1.0)
        tag!(reg[1], :consume, 2)
    end
    @resumable function deleting_query_receiver(sim, reg, LOG, receiver_id)
        result = @yield querydelete_wait!(reg, :consume, ❓)
        push!(LOG, (receiver_id, result.tag[2], now(sim)))
    end

    reg = Register(1)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    LOG = []

    @process deleting_query_receiver(sim, reg, LOG, 1)
    @process deleting_query_receiver(sim, reg, LOG, 2)
    @process two_tag_sender(sim, reg)

    run(sim, 1.1)
    @test length(LOG) == 1
    @test query(reg, :consume, 1) === nothing

    run(sim, 2.1)
    @test length(LOG) == 2
    @test sort!([entry[2] for entry in LOG]) == [1, 2]
    @test query(reg, :consume, 2) === nothing
end

@testset "query_wait consumers can retry after a stale checked deletion" begin
    @resumable function checked_delete_sender(sim, reg)
        @yield timeout(sim, 1.0)
        tag!(reg[1], :checked, 1)
        @yield timeout(sim, 1.0)
        tag!(reg[1], :checked, 2)
    end
    @resumable function checked_delete_receiver(sim, reg, LOG, receiver_id)
        while true
            result = @yield query_wait(reg, :checked, ❓)
            deleted = querydelete!(result.slot, result.tag)
            if !isnothing(deleted)
                push!(LOG, (receiver_id, deleted.tag[2], now(sim)))
                return
            end
        end
    end

    reg = Register(1)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    LOG = []

    @process checked_delete_receiver(sim, reg, LOG, 1)
    @process checked_delete_receiver(sim, reg, LOG, 2)
    @process checked_delete_sender(sim, reg)

    run(sim, 1.1)
    @test length(LOG) == 1
    @test query(reg, :checked, 1) === nothing

    run(sim, 2.1)
    @test length(LOG) == 2
    @test sort!([entry[2] for entry in LOG]) == [1, 2]
    @test query(reg, :checked, 2) === nothing
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
