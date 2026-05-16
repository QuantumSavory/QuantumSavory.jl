using QuantumSavory.ResumableFunctions: @resumable, @yield
using QuantumSavory.ConcurrentSim: @process, run

SUITE["messagebuffer"] = BenchmarkGroup(["messagebuffer"])

function prepare_messagebuffer()
    net = RegisterNet([Register(1)])
    return messagebuffer(net[1])
end

function put_messagebuffer_batch!(mb, count::Int)
    for i in 1:count
        put!(mb, Tag(:bench_messagebuffer, i, i + 1))
    end
    return length(mb.buffer)
end

@resumable function _messagebuffer_onchange_waiter(sim, mb, count::Int)
    for _ in 1:count
        @yield onchange(mb, Tag)
    end
end

function prepare_prebuffered_onchange(count::Int)
    mb = prepare_messagebuffer()
    sim = get_time_tracker(mb)

    for i in 1:count
        put!(mb, Tag(:bench_prebuffered, i))
    end
    @process _messagebuffer_onchange_waiter(sim, mb, count)

    return sim
end

@resumable function _messagebuffer_channel_sender(sim, ch, count::Int)
    for i in 1:count
        put!(ch, Tag(:bench_channel_delivery, i))
    end
end

function prepare_channel_delivery(count::Int)
    net = RegisterNet([Register(1), Register(1)], classical_delay=1.0, quantum_delay=1.0)
    sim = get_time_tracker(net)
    ch = channel(net, 1 => 2)

    # Materialize the destination buffer so the channel take loop is registered.
    messagebuffer(net, 2)
    @process _messagebuffer_channel_sender(sim, ch, count)

    return sim
end

SUITE["messagebuffer"]["direct_put"] = BenchmarkGroup(["direct_put"])
for count in (1, 8, 64, 256)
    label = "messages_$(count)"
    SUITE["messagebuffer"]["direct_put"][label] =
        @benchmarkable put_messagebuffer_batch!(_mb, $count) setup=(_mb = prepare_messagebuffer()) evals=1
end

SUITE["messagebuffer"]["prebuffered_onchange"] = BenchmarkGroup(["prebuffered_onchange"])
for count in (1, 8, 64, 256)
    label = "messages_$(count)"
    SUITE["messagebuffer"]["prebuffered_onchange"][label] =
        @benchmarkable run(sim) setup=(sim = prepare_prebuffered_onchange($count)) evals=1
end

SUITE["messagebuffer"]["channel_delivery"] = BenchmarkGroup(["channel_delivery"])
for count in (1, 8, 64, 256)
    label = "messages_$(count)"
    SUITE["messagebuffer"]["channel_delivery"][label] =
        @benchmarkable run(sim) setup=(sim = prepare_channel_delivery($count)) evals=1
end
