using QuantumSavory.ConcurrentSim: @process, run

SUITE["protocolzoo"] = BenchmarkGroup(["protocolzoo"])
SUITE["protocolzoo"]["qtcp"] = BenchmarkGroup(["qtcp"])

function _count_qtcp_tags!(mb, tag_type, flow_uuid)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, flow_uuid, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

function _launch_qtcp_controllers!(net, end_nodes)
    for node in end_nodes
        @process EndNodeController(net, node)()
    end
    for node in 1:length(net.registers)
        @process NetworkNodeController(net, node)()
    end
    for edge in QuantumSavory.Graphs.edges(net)
        @process LinkController(net, edge.src, edge.dst)()
    end
end

function prepare_qtcp_chain(; n_nodes::Int, regsize::Int, npairs::Int, uuid::Int)
    net = RegisterNet([Register(regsize) for _ in 1:n_nodes]; classical_delay=1e-6)
    sim = get_time_tracker(net)
    _launch_qtcp_controllers!(net, (1, n_nodes))
    put!(net[1], Flow(src=1, dst=n_nodes, npairs=npairs, uuid=uuid))
    return (; sim, net, npairs, uuid)
end

function run_qtcp_chain!(state; until)
    run(state.sim, until)
    src_delivered = _count_qtcp_tags!(messagebuffer(state.net, 1), QTCPPairBegin, state.uuid)
    dst_delivered = _count_qtcp_tags!(messagebuffer(state.net, length(state.net.registers)), QTCPPairEnd, state.uuid)
    @assert src_delivered == state.npairs
    @assert dst_delivered == state.npairs
    return nothing
end

function prepare_qtcp_same_chain_flows(; n_nodes::Int, regsize::Int, npairs::Int)
    net = RegisterNet([Register(regsize) for _ in 1:n_nodes]; classical_delay=1e-6)
    sim = get_time_tracker(net)
    _launch_qtcp_controllers!(net, (1, 2, n_nodes - 1, n_nodes))
    put!(net[1], Flow(src=1, dst=n_nodes, npairs=npairs, uuid=301))
    put!(net[2], Flow(src=2, dst=n_nodes - 1, npairs=npairs, uuid=302))
    return (; sim, net, npairs)
end

function run_qtcp_same_chain_flows!(state; until)
    run(state.sim, until)
    @assert _count_qtcp_tags!(messagebuffer(state.net, 1), QTCPPairBegin, 301) == state.npairs
    @assert _count_qtcp_tags!(messagebuffer(state.net, length(state.net.registers)), QTCPPairEnd, 301) == state.npairs
    @assert _count_qtcp_tags!(messagebuffer(state.net, 2), QTCPPairBegin, 302) == state.npairs
    @assert _count_qtcp_tags!(messagebuffer(state.net, length(state.net.registers) - 1), QTCPPairEnd, 302) == state.npairs
    return nothing
end

# Complete QTCP protocol runs cover controller setup, link-level requests,
# forwarding, hop-by-hop delivery, and final source/destination tag queries.
SUITE["protocolzoo"]["qtcp"]["chain_5_nodes_4_pairs"] = @benchmarkable run_qtcp_chain!(state; until=250.0) setup=(state = prepare_qtcp_chain(; n_nodes=5, regsize=8, npairs=4, uuid=201)) evals=1

SUITE["protocolzoo"]["qtcp"]["chain_8_nodes_4_pairs"] = @benchmarkable run_qtcp_chain!(state; until=450.0) setup=(state = prepare_qtcp_chain(; n_nodes=8, regsize=10, npairs=4, uuid=202)) evals=1

SUITE["protocolzoo"]["qtcp"]["same_chain_two_flows"] = @benchmarkable run_qtcp_same_chain_flows!(state; until=300.0) setup=(state = prepare_qtcp_same_chain_flows(; n_nodes=5, regsize=12, npairs=2)) evals=1
