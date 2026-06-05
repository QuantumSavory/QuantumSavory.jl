using Test
using QuantumSavory
using ConcurrentSim
using ResumableFunctions

@testset "Change notification functionality" begin

@testset "Register tag wait" begin
    reg = Register(2)
    sim = get_time_tracker(reg)
    LOG = []

    @resumable function tagger(sim)
        push!(LOG, (now(sim), "tagger: start"))
        @yield timeout(sim, 10)
        tag!(reg[1], :first)
        push!(LOG, (now(sim), "tagger: tagged 1"))
        @yield timeout(sim, 5)
        tag!(reg[1], :second)
        push!(LOG, (now(sim), "tagger: tagged 2"))
    end

    @resumable function watcher(sim)
        push!(LOG, (now(sim), "watcher: start"))
        @yield onchange(reg[1], Tag)
        push!(LOG, (now(sim), "watcher: got first tag"))
        @yield onchange(reg[1], Tag)
        push!(LOG, (now(sim), "watcher: got second tag"))
    end

    @process tagger(sim)
    @process watcher(sim)

    run(sim)

    expected_LOG = [
        (0.0, "tagger: start"),
        (0.0, "watcher: start"),
        (10.0, "tagger: tagged 1"),
        (10.0, "watcher: got first tag"),
        (15.0, "tagger: tagged 2"),
        (15.0, "watcher: got second tag")
    ]
    @test length(LOG) == length(expected_LOG)
    for i in 1:length(LOG)
        @test LOG[i] == expected_LOG[i]
    end
end

@testset "Register tag waiter inference" begin
    reg = Register(1)
    waiter = reg.tag_waiter[]

    proc = @inferred onchange(reg)
    @test proc isa ConcurrentSim.Process

    proc = @inferred onchange(reg[1], Tag)
    @test proc isa ConcurrentSim.Process

    @test @inferred(unlock(waiter)) === nothing

    id = @inferred tag!(reg[1], :first)
    @test id isa Int128

    deleted = @inferred untag!(reg, id)
    @test deleted.tag == Tag(:first)
end

@testset "MessageBuffer wait" begin
    net = RegisterNet([Register(2), Register(2)], classical_delay=1, quantum_delay=1)
    sim = get_time_tracker(net)
    mb = messagebuffer(net[1])
    ch = channel(net, 2=>1)
    LOG = []

    @resumable function sender(sim)
        push!(LOG, (now(sim), "sender: start"))
        @yield timeout(sim, 10)
        put!(ch, Tag(:first))
        push!(LOG, (now(sim), "sender: sent 1"))
        @yield timeout(sim, 5)
        put!(ch, Tag(:second))
        push!(LOG, (now(sim), "sender: sent 2"))
        @yield timeout(sim, 3)
        put!(mb, Tag(:third))
        push!(LOG, (now(sim), "sender: put 3 directly"))
    end

    @resumable function receiver(sim)
        push!(LOG, (now(sim), "receiver: start"))
        @yield onchange(mb)
        push!(LOG, (now(sim), "receiver: got message"))
        @yield onchange(mb)
        push!(LOG, (now(sim), "receiver: got second message"))
        @yield onchange(mb)
        push!(LOG, (now(sim), "receiver: got third message"))
    end

    @process sender(sim)
    @process receiver(sim)

    run(sim)

    expected_LOG = [
        (0.0, "sender: start"),
        (0.0, "receiver: start"),
        (10.0, "sender: sent 1"),
        (11.0, "receiver: got message"),
        (15.0, "sender: sent 2"),
        (16.0, "receiver: got second message"),
        (18.0, "sender: put 3 directly"),
        (18.0, "receiver: got third message")
    ]

    @test length(LOG) == length(expected_LOG)
    for i in 1:length(LOG)
        @test LOG[i] == expected_LOG[i]
    end
end

@testset "MessageBuffer wait on either buffer" begin
    net = RegisterNet([Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    mb1 = messagebuffer(net[1])
    mb2 = messagebuffer(net[2])
    LOG = []

    @resumable function sender1(sim)
        push!(LOG, (now(sim), "sender1: start"))
        @yield timeout(sim, 10)
        put!(mb1, Tag(:first_from_sender1))
        push!(LOG, (now(sim), "sender1: sent message"))
        @yield timeout(sim, 10)
        put!(mb1, Tag(:second_from_sender1))
        push!(LOG, (now(sim), "sender1: sent second message"))
    end

    @resumable function sender2(sim)
        push!(LOG, (now(sim), "sender2: start"))
        @yield timeout(sim, 5)
        put!(mb2, Tag(:first_from_sender2))
        push!(LOG, (now(sim), "sender2: sent message"))
        @yield timeout(sim, 20)
        put!(mb2, Tag(:second_from_sender2))
        push!(LOG, (now(sim), "sender2: sent second message"))
    end

    @resumable function receiver(sim)
        push!(LOG, (now(sim), "receiver: start"))

        while true
            p1 = onchange(mb1)
            p2 = onchange(mb2)
            @yield (p1 | p2)

            push!(LOG, (now(sim), "receiver: got message from sender"))
        end

        push!(LOG, (now(sim), "receiver: finished"))
    end

    @process sender1(sim)
    @process sender2(sim)
    @process receiver(sim)

    run(sim)

    expected_LOG = [
        (0.0, "sender1: start"),
        (0.0, "sender2: start"),
        (0.0, "receiver: start"),
        (5.0, "sender2: sent message"),
        (5.0, "receiver: got message from sender"),
        (10.0, "sender1: sent message"),
        (10.0, "receiver: got message from sender"),
        (20.0, "sender1: sent second message"),
        (20.0, "receiver: got message from sender"),
        (25.0, "sender2: sent second message"),
        (25.0, "receiver: got message from sender"),
    ]

    @test length(LOG) == length(expected_LOG)
    for i in 1:length(LOG)
        @test LOG[i] == expected_LOG[i]
    end
end

end
