SUITE["channels"] = BenchmarkGroup(["channels"])

function prepare_classical_channel_delivery(; n_messages::Int, delay::Float64=0.0)
    net = RegisterNet([Register(1), Register(1)]; classical_delay=delay)
    sim = get_time_tracker(net)
    ch = channel(net, 1=>2)
    for i in 1:n_messages
        put!(ch, Tag(:bench_channel, i))
    end
    return sim, messagebuffer(net, 2), n_messages
end

function run_classical_channel_delivery(sim, mb, n_messages)
    run(sim)
    @assert length(QuantumSavory.peektags(mb)) == n_messages
end

function prepare_forwarded_channel_delivery(; n_messages::Int, delay::Float64=0.0)
    net = RegisterNet([Register(1), Register(1), Register(1)]; classical_delay=delay)
    sim = get_time_tracker(net)
    ch = channel(net, 1=>3; permit_forward=true)
    for i in 1:n_messages
        put!(ch, Tag(:bench_forwarded_channel, i))
    end
    return sim, messagebuffer(net, 3), n_messages
end

function run_forwarded_channel_delivery(sim, mb, n_messages)
    run(sim)
    @assert length(QuantumSavory.peektags(mb)) == n_messages
end

function prepare_quantum_channel_delivery(; n_messages::Int, delay::Float64=0.0)
    net = RegisterNet([Register(n_messages), Register(n_messages)]; quantum_delay=delay)
    sim = get_time_tracker(net)
    qch = qchannel(net, 1=>2)
    for i in 1:n_messages
        initialize!(net[1,i])
        put!(qch, net[1,i])
        take!(qch, net[2,i])
    end
    return sim, net, n_messages
end

function run_quantum_channel_delivery(sim, net, n_messages)
    run(sim)
    @assert all(!isassigned(net[1,i]) for i in 1:n_messages)
    @assert all(isassigned(net[2,i]) for i in 1:n_messages)
end

SUITE["channels"]["accessors"] = BenchmarkGroup(["accessors"])
const _QS_CHANNEL_BENCH_NET = RegisterNet([Register(1), Register(1), Register(1)])
const _QS_CHANNEL_BENCH_PAIR = _QS_CHANNEL_BENCH_NET[1]=>_QS_CHANNEL_BENCH_NET[2]
const _QS_CHANNEL_BENCH_REG2 = _QS_CHANNEL_BENCH_NET[2]
SUITE["channels"]["accessors"]["classical_by_index"] = @benchmarkable channel($_QS_CHANNEL_BENCH_NET, 1=>2)
SUITE["channels"]["accessors"]["classical_by_register"] = @benchmarkable channel($_QS_CHANNEL_BENCH_NET, $_QS_CHANNEL_BENCH_PAIR)
SUITE["channels"]["accessors"]["classical_forwarder"] = @benchmarkable channel($_QS_CHANNEL_BENCH_NET, 1=>3; permit_forward=true)
SUITE["channels"]["accessors"]["quantum_by_index"] = @benchmarkable qchannel($_QS_CHANNEL_BENCH_NET, 1=>2)
SUITE["channels"]["accessors"]["messagebuffer_by_index"] = @benchmarkable messagebuffer($_QS_CHANNEL_BENCH_NET, 2)
SUITE["channels"]["accessors"]["messagebuffer_by_register"] = @benchmarkable messagebuffer($_QS_CHANNEL_BENCH_REG2)

SUITE["channels"]["classical_delivery"] = BenchmarkGroup(["classical_delivery"])
for n_messages in (1, 16, 128)
    label = "messages_$(n_messages)"
    SUITE["channels"]["classical_delivery"][label] =
        @benchmarkable run_classical_channel_delivery(sim, mb, n) setup=((sim, mb, n) = prepare_classical_channel_delivery(; n_messages=$n_messages)) evals=1
end

SUITE["channels"]["forwarded_delivery"] = BenchmarkGroup(["forwarded_delivery"])
for n_messages in (1, 16, 128)
    label = "messages_$(n_messages)"
    SUITE["channels"]["forwarded_delivery"][label] =
        @benchmarkable run_forwarded_channel_delivery(sim, mb, n) setup=((sim, mb, n) = prepare_forwarded_channel_delivery(; n_messages=$n_messages)) evals=1
end

SUITE["channels"]["quantum_delivery"] = BenchmarkGroup(["quantum_delivery"])
for n_messages in (1, 8, 32)
    label = "messages_$(n_messages)"
    SUITE["channels"]["quantum_delivery"][label] =
        @benchmarkable run_quantum_channel_delivery(sim, net, n) setup=((sim, net, n) = prepare_quantum_channel_delivery(; n_messages=$n_messages)) evals=1
end
