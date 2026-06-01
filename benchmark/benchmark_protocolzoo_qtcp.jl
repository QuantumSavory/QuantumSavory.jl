SUITE["protocolzoo"] = BenchmarkGroup(["protocolzoo"])
SUITE["protocolzoo"]["qtcp"] = BenchmarkGroup(["qtcp"])

function prepare_qtcp_chain(; n_nodes, regsize, src, dst, npairs, flow_uuid)
    registers = [Register(regsize) for _ in 1:n_nodes]
    net = RegisterNet(registers; classical_delay=1e-6)
    sim = get_time_tracker(net)

    @process EndNodeController(sim, net, src)()
    @process EndNodeController(sim, net, dst)()

    for node in 1:n_nodes
        @process NetworkNodeController(sim, net, node)()
    end

    for node in 1:(n_nodes - 1)
        @process LinkController(sim=sim, net=net, nodeA=node, nodeB=node + 1)()
    end

    put!(net[src], Flow(src=src, dst=dst, npairs=npairs, uuid=flow_uuid))
    return sim, net
end

function count_qtcp_pairs!(mb, tag_type, flow_uuid)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, flow_uuid, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

function run_qtcp_chain!(ctx; src, dst, npairs, flow_uuid, runtime)
    sim, net = ctx
    run(sim, runtime)

    starts = count_qtcp_pairs!(messagebuffer(net, src), QTCPPairBegin, flow_uuid)
    ends = count_qtcp_pairs!(messagebuffer(net, dst), QTCPPairEnd, flow_uuid)

    @assert starts == npairs
    @assert ends == npairs
    return starts, ends
end

# End-to-end protocol benchmarks cover controller scheduling, link handling, and pair delivery.
SUITE["protocolzoo"]["qtcp"]["chain_3_single_pair"] = @benchmarkable run_qtcp_chain!(
    ctx;
    src=1,
    dst=3,
    npairs=1,
    flow_uuid=1301,
    runtime=200.0,
) setup=(
    ctx = prepare_qtcp_chain(;
        n_nodes=3,
        regsize=6,
        src=1,
        dst=3,
        npairs=1,
        flow_uuid=1301,
    )
) evals=1

SUITE["protocolzoo"]["qtcp"]["chain_5_four_pairs"] = @benchmarkable run_qtcp_chain!(
    ctx;
    src=1,
    dst=5,
    npairs=4,
    flow_uuid=1305,
    runtime=1000.0,
) setup=(
    ctx = prepare_qtcp_chain(;
        n_nodes=5,
        regsize=10,
        src=1,
        dst=5,
        npairs=4,
        flow_uuid=1305,
    )
) evals=1
