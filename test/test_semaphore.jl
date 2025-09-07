@testitem "AsymmetricSemaphore functionality" begin

using QuantumSavory: AsymmetricSemaphore
using ConcurrentSim
using ResumableFunctions
import Base: unlock, lock

##

@testset "AsymmetricSemaphore" begin
sim = Simulation()
waiter = AsymmetricSemaphore(sim)
LOG = []

@resumable function trigger(sim)
    push!(LOG, (now(sim), "t: start"))
    @yield timeout(sim, 10)
    push!(LOG, (now(sim), "t: waited 10"))
    unlock(waiter)
    push!(LOG, (now(sim), "t: first trigger"))
    @yield timeout(sim, 20)
    push!(LOG, (now(sim), "t: waited 20"))
    unlock(waiter)
    push!(LOG, (now(sim), "t: second trigger"))
    @yield timeout(sim, 15)
    push!(LOG, (now(sim), "t: waited 15"))
    unlock(waiter)
    push!(LOG, (now(sim), "t: third trigger"))
    push!(LOG, (now(sim), "t: end"))
end

@resumable function proc1(sim)
    push!(LOG, (now(sim), "proc1: start"))
    @yield lock(waiter)
    push!(LOG, (now(sim), "proc1: first lock"))
    @yield lock(waiter)
    push!(LOG, (now(sim), "proc1: second lock"))
    @yield timeout(sim, 10)
    push!(LOG, (now(sim), "proc1: waited 10"))
    @yield lock(waiter)
    push!(LOG, (now(sim), "proc1: third lock"))
    push!(LOG, (now(sim), "proc1: end"))
end

@resumable function proc2(sim)
    push!(LOG, (now(sim), "proc2: start"))
    @yield lock(waiter)
    push!(LOG, (now(sim), "proc2: first lock"))
    @yield timeout(sim, 25)
    push!(LOG, (now(sim), "proc2: waited 25"))
    @yield lock(waiter)
    push!(LOG, (now(sim), "proc2: second lock")) # should be after third trigger
    push!(LOG, (now(sim), "proc2: end"))
end

@process trigger(sim)
@process proc1(sim)
@process proc2(sim)

run(sim)


expected_LOG = [
    (0.0, "t: start"),
    (0.0, "proc1: start"),
    (0.0, "proc2: start"),
    (10.0, "t: waited 10"),
    (10.0, "t: first trigger"),
    (10.0, "proc1: first lock"),
    (10.0, "proc2: first lock"),
    (30.0, "t: waited 20"),
    (30.0, "t: second trigger"),
    (30.0, "proc1: second lock"),
    (35.0, "proc2: waited 25"),
    (40.0, "proc1: waited 10"),
    (45.0, "t: waited 15"),
    (45.0, "t: third trigger"),
    (45.0, "t: end"),
    (45.0, "proc2: second lock"),
    (45.0, "proc2: end"),
    (45.0, "proc1: third lock"),
    (45.0, "proc1: end")
]


@test length(LOG) == length(expected_LOG)

for i in 1:length(LOG)
    @test LOG[i] == expected_LOG[i]
end

end

@testset "Multiple AsymmetricSemaphores" begin
sim = Simulation()
waiter1 = AsymmetricSemaphore(sim)
waiter2 = AsymmetricSemaphore(sim)
LOG = []

@resumable function trigger(sim)
    push!(LOG, (now(sim), "t: start"))
    @yield timeout(sim, 10)
    push!(LOG, (now(sim), "t: waited 10"))
    unlock(waiter1)
    push!(LOG, (now(sim), "t: unlock first waiter"))
    @yield timeout(sim, 5)
    push!(LOG, (now(sim), "t: waited 5"))
    unlock(waiter2)
    push!(LOG, (now(sim), "t: unlock second waiter"))
    push!(LOG, (now(sim), "t: end"))
end

@resumable function proc1(sim)
    push!(LOG, (now(sim), "proc1: start"))
    @yield lock(waiter1) | lock(waiter2)
    push!(LOG, (now(sim), "proc1: got a lock"))
    push!(LOG, (now(sim), "proc1: end"))
end

@resumable function proc2(sim)
    push!(LOG, (now(sim), "proc2: start"))
    @yield lock(waiter1) & lock(waiter2)
    push!(LOG, (now(sim), "proc2: got both locks"))
    push!(LOG, (now(sim), "proc2: end"))
end
@process trigger(sim)
@process proc1(sim)
@process proc2(sim)

run(sim)

expected_LOG = [
(0.0, "t: start"),
(0.0, "proc1: start"),
(0.0, "proc2: start"),
(10.0, "t: waited 10"),
(10.0, "t: unlock first waiter"),
(10.0, "proc1: got a lock"),
(10.0, "proc1: end"),
(15.0, "t: waited 5"),
(15.0, "t: unlock second waiter"),
(15.0, "t: end"),
(15.0, "proc2: got both locks"),
(15.0, "proc2: end")
]

@test length(LOG) == length(expected_LOG)

for i in 1:length(LOG)
    @test LOG[i] == expected_LOG[i]
end

end

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

@testset "MessageBuffer wait - this does NOT use the AsymmetricSemaphore -- an alternative equivalent implementation" begin
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

##

@testset "AsymmetricSemaphore with multiple senders and separate message buffers -- this does NOT use the AsymmetricSemaphore -- an alternative equivalent implementation" begin
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

        # Wait for messages from either sender
        while true
            # Create processes for waiting on each message buffer
            p1 = onchange(mb1)
            p2 = onchange(mb2)

            # Wait for either process to complete
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

##

@testset "multiple waiters/receivers for the same sender with AsymmetricSemaphore" begin
    sim = Simulation()
    semaphore = QuantumSavory.AsymmetricSemaphore(sim)

    @resumable function sender(sim, semaphore)
        # Send 10 signals, one time unit apart
        for i in 1:10
            @yield timeout(sim, 1.0)
            unlock(semaphore)
        end
    end

    @resumable function receiver(sim, semaphore, id)
        count = 0
        while true
            @yield lock(semaphore)
            #println("this should not loop too much but it loops infinitely $id $count")
            count += 1
        end
        @test count < 20
    end

    # Start the sender and 4 receivers
    @process sender(sim, semaphore)
    @process receiver(sim, semaphore, 1)
    @process receiver(sim, semaphore, 2)
    @process receiver(sim, semaphore, 3)
    @process receiver(sim, semaphore, 4)

    run(sim, 20.0)

    # The test passes if we get here without infinite loops
    @test true
end

##

@testset "multiple waiters/receivers for the same sender with AsymmetricSemaphore -- and yielding twice" begin
    sim = Simulation()
    semaphore = QuantumSavory.AsymmetricSemaphore(sim)

    @resumable function sender(sim, semaphore)
        # Send 10 signals, one time unit apart
        for i in 1:10
            @yield timeout(sim, 1.0)
            unlock(semaphore)
            unlock(semaphore) # this second yield can cause infinite loops if the semaphore is not implemented correctly
        end
    end

    @resumable function receiver(sim, semaphore, id)
        count = 0
        while true
            @yield lock(semaphore)
            #println("this should not loop too much but it loops infinitely $id $count")
            count += 1
        end
        @test count < 20
    end

    # Start the sender and 4 receivers
    @process sender(sim, semaphore)
    @process receiver(sim, semaphore, 1)
    @process receiver(sim, semaphore, 2)
    @process receiver(sim, semaphore, 3)
    @process receiver(sim, semaphore, 4)

    run(sim, 20.0)

    # The test passes if we get here without infinite loops
    @test true
end

##

@testset "particularly nested ordering of unlocks and waits" begin
    sim = Simulation()
    semaphore = QuantumSavory.AsymmetricSemaphore(sim)

    waiter_unlocked_count = Ref(0)

    @resumable function unlock_at(sim, when)
        @yield timeout(sim, when)
        unlock(semaphore)
    end

    @resumable function wait_at(sim, when)
        @yield timeout(sim, when)
        @yield lock(semaphore)
        waiter_unlocked_count[] += 1
    end

    @process unlock_at(sim, 1.0)
    @process unlock_at(sim, 1.0)
    @process unlock_at(sim, 1.5)
    @process wait_at(sim, 2.0)
    @process wait_at(sim, 2.0)
    @process wait_at(sim, 2.0)
    @process unlock_at(sim, 2.0)
    @process unlock_at(sim, 2.0)

    run(sim, 100.0)
    # The test passes if we get here without infinite loops
end

##

end
