using Test
using QuantumSavory
using QuantumSavory: tag_types
using QuantumSavory.ProtocolZoo
using ResumableFunctions, ConcurrentSim

@testset "Message Buffer" begin

@testset "a receiver can wait for changes and then delete a specific tag" begin
    net = RegisterNet([Register(3), Register(2), Register(3)])
    env = get_time_tracker(net)

    @resumable function receive_tags(env)
        while true
            mb = messagebuffer(net, 2)
            @yield onchange(mb)
            querydelete!(mb, :second_tag, ❓, ❓)
        end
    end

    @resumable function send_tags(env)
        @yield timeout(env, 1.0)
        put!(channel(net, 1=>2), Tag(:my_tag))
        @yield timeout(env, 2.0)
        put!(channel(net, 3=>2), Tag(:second_tag, 123, 456))
    end

    @process send_tags(env)
    @process receive_tags(env)
    run(env, 10)

    @test query(messagebuffer(net, 2), :second_tag, ❓, ❓) === nothing
    @test query(messagebuffer(net, 2), :my_tag).tag == Tag(:my_tag)
end

@testset "put! accepts both concrete tag values and tag-like payloads" begin
    net = RegisterNet([Register(4), Register(4)])
    sim = get_time_tracker(net)

    put!(channel(net, 2=>1), SwitchRequest(2, 3))
    put!(channel(net, 2=>1), Tag(SwitchRequest(2, 3)))
    put!(messagebuffer(net[1]), Tag(SwitchRequest(2, 3)))
    put!(messagebuffer(net[1]), SwitchRequest(2, 3))

    run(sim, 10)

    @test QuantumSavory.peektags(messagebuffer(net, 1)) == [
        Tag(SwitchRequest(2, 3)),
        Tag(SwitchRequest(2, 3)),
        Tag(SwitchRequest(2, 3)),
        Tag(SwitchRequest(2, 3)),
    ]
    @test_throws "does not support `tag!`" tag!(
        messagebuffer(net, 1), EntanglementCounterpart, 1, 10
    )
end

@testset "future arrivals wake waiters that are already blocked" begin
    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    mb = messagebuffer(reg)
    wake_log = []

    @resumable function wait_without_type(sim, mb, wake_log)
        @yield onchange(mb)
        push!(wake_log, ("onchange(mb)", now(sim)))
    end

    @resumable function wait_with_tag_type(sim, mb, wake_log)
        @yield onchange(mb, Tag)
        push!(wake_log, ("onchange(mb, Tag)", now(sim)))
    end

    @resumable function sender(sim, mb)
        @yield timeout(sim, 5.0)
        put!(mb, Tag(:hello))
    end

    @process wait_without_type(sim, mb, wake_log)
    @process wait_with_tag_type(sim, mb, wake_log)
    @process sender(sim, mb)

    run(sim)

    # One arriving message wakes every task that was already blocked on the
    # MessageBuffer. `onchange(mb, Tag)` currently behaves the same way.
    @test Set(first.(wake_log)) == Set(["onchange(mb)", "onchange(mb, Tag)"])
    @test length(wake_log) == 2
    @test all(last(entry) == 5.0 for entry in wake_log)
    @test query(mb, :hello).tag == Tag(:hello)
end

@testset "a message that is already buffered wakes a later waiter immediately" begin
    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    mb = messagebuffer(reg)

    # The message is buffered before any waiter exists.
    put!(mb, Tag(:already_here))

    wait_log = []

    @resumable function receiver(sim, mb, wait_log)
        push!(wait_log, ("receiver started waiting", now(sim)))
        @yield onchange(mb)
        push!(wait_log, ("receiver woke", now(sim)))
    end

    @process receiver(sim, mb, wait_log)
    run(sim)

    @test wait_log == [
        ("receiver started waiting", 0.0),
        ("receiver woke", 0.0),
    ]

    # Waiting does not consume the buffered tag. It only signals that the buffer
    # changed and that a query is worth retrying.
    @test query(mb, :already_here).tag == Tag(:already_here)
end

@testset "buffered arrivals are counted one by one for later waiters" begin
    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    mb = messagebuffer(reg)

    # Two messages arrive before anyone waits on the buffer.
    put!(mb, Tag(:first))
    put!(mb, Tag(:second))

    wake_times = Float64[]

    @resumable function sender(sim, mb)
        @yield timeout(sim, 5.0)
        put!(mb, Tag(:third))
    end

    @resumable function receiver(sim, mb, wake_times)
        # The first two waits should finish immediately because two arrivals were
        # already buffered. The third wait should block until the future arrival.
        @yield onchange(mb)
        push!(wake_times, now(sim))

        @yield onchange(mb)
        push!(wake_times, now(sim))

        @yield onchange(mb)
        push!(wake_times, now(sim))
    end

    @process receiver(sim, mb, wake_times)
    @process sender(sim, mb)
    run(sim)

    @test wake_times == [0.0, 0.0, 5.0]
    @test QuantumSavory.peektags(mb) == [Tag(:first), Tag(:second), Tag(:third)]
end

@testset "deprecated wait(mb) keeps the same queued-wakeup behavior" begin
    reg = Register(10)
    net = RegisterNet([reg])
    sim = get_time_tracker(net)
    mb = messagebuffer(reg)

    put!(mb, Tag(:already_here))
    wake_times = Float64[]

    @resumable function receiver(sim, mb, wake_times)
        @yield wait(mb)
        push!(wake_times, now(sim))
    end

    @process receiver(sim, mb, wake_times)
    run(sim)

    @test wake_times == [0.0]
end

end
