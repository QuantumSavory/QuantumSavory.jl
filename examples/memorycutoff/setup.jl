using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using Random

"""
    prepare_simulation(; kwargs...)

Build a small repeater-chain simulation for exploring the memory-cutoff
tradeoff. Neighboring nodes continuously generate Bell pairs, intermediate
nodes swap pairs toward the end users, trackers reconcile classical messages,
and cutoff protocols discard qubits that have waited past `retention_time`.
"""
function prepare_simulation(;
    nodes::Int = 4,
    regsize::Int = 4,
    T2::Float64 = 40.0,
    success_prob::Float64 = 0.15,
    attempt_time::Float64 = 0.05,
    retention_time::Float64 = 5.0,
    agelimit_buffer::Float64 = 0.5,
    retry_lock_time::Float64 = 0.05,
    cutoff_period::Float64 = 0.1,
    consumer_period::Float64 = 0.1,
    random_seed::Int = 1,
)
    nodes >= 3 || throw(ArgumentError("nodes must be at least 3"))
    regsize >= 2 || throw(ArgumentError("regsize must be at least 2"))
    success_prob > 0 || throw(ArgumentError("success_prob must be positive"))
    attempt_time > 0 || throw(ArgumentError("attempt_time must be positive"))
    retention_time > 0 || throw(ArgumentError("retention_time must be positive"))
    agelimit_buffer >= 0 || throw(ArgumentError("agelimit_buffer must be nonnegative"))

    Random.seed!(random_seed)

    graph = path_graph(nodes)
    registers = [Register(regsize, T2Dephasing(T2)) for _ in 1:nodes]
    net = RegisterNet(graph, registers)
    sim = get_time_tracker(net)

    for (; src, dst) in edges(net)
        entangler = EntanglerProt(
            sim, net, src, dst;
            rounds = -1,
            randomize = true,
            success_prob,
            attempt_time,
            retry_lock_time,
        )
        @process entangler()
    end

    agelimit = max(retention_time - agelimit_buffer, eps(Float64))
    for node in 2:(nodes - 1)
        swapper = SwapperProt(
            sim, net, node;
            nodeL = <(node),
            nodeH = >(node),
            chooseL = argmin,
            chooseH = argmax,
            rounds = -1,
            retry_lock_time,
            agelimit,
        )
        @process swapper()
    end

    for node in vertices(net)
        tracker = EntanglementTracker(sim, net, node)
        @process tracker()
    end

    consumer = EntanglementConsumer(sim, net, 1, nodes; period = consumer_period)
    @process consumer()

    for node in vertices(net)
        cutoff = CutoffProt(
            sim, net, node;
            retention_time,
            period = cutoff_period,
            announce = true,
        )
        @process cutoff()
    end

    return (; sim, net, consumer, nodes, regsize, retention_time, agelimit, success_prob, attempt_time, T2)
end

function consumer_stats(consumer)
    delivered = length(consumer._log)
    if iszero(delivered)
        return (delivered = 0, mean_zz = NaN, mean_xx = NaN, final_time = 0.0, mean_interval = NaN)
    end

    times = [entry.t for entry in consumer._log]
    intervals = diff([0.0; times])
    return (
        delivered = delivered,
        mean_zz = sum(entry.obs1 for entry in consumer._log) / delivered,
        mean_xx = sum(entry.obs2 for entry in consumer._log) / delivered,
        final_time = last(times),
        mean_interval = sum(intervals) / length(intervals),
    )
end

function run_cutoff_point(; duration::Float64 = 40.0, kwargs...)
    scenario = prepare_simulation(; kwargs...)
    run(scenario.sim, duration)
    stats = consumer_stats(scenario.consumer)
    return merge(NamedTuple{(:retention_time, :agelimit, :success_prob, :T2)}(
        (scenario.retention_time, scenario.agelimit, scenario.success_prob, scenario.T2),
    ), stats)
end
