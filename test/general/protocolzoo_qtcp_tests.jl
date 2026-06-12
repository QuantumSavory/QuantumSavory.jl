using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using Graphs
using Random
using Test

function count_matching_tags!(mb, tag_type, pattern...)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, pattern...))
        n += 1
    end
    return n
end

function setup_qtcp_network(graph, regsize; classical_delay=1e-6, end_nodes=nothing, EndNodeControllerType=EndNodeController)
    registers = [Register(regsize) for _ in vertices(graph)]
    net = RegisterNet(graph, registers; classical_delay)
    sim = get_time_tracker(net)

    if isnothing(end_nodes)
        end_nodes = collect(vertices(graph))
    end

    for node in end_nodes
        @process EndNodeControllerType(net, node)()
    end
    for node in vertices(graph)
        @process NetworkNodeController(net, node)()
    end
    for edge in edges(net)
        @process LinkController(net, edge.src, edge.dst)()
    end

    return sim, net
end

@testset "QTCP" begin

##


@testset "EndNodeController turning Flow into QDatagram" begin
    # Create registers with a few qubits each
    registers = [Register(5) for _ in 1:2]

    # Create network with registers
    net = RegisterNet(registers)

    # Get simulation from network
    sim = get_time_tracker(net)

    # Create only EndNodeController at node 1 (source)
    end_controller = EndNodeController(sim, net, 1)
    @process end_controller()

    # Create a test flow
    test_flow = Flow(
        src=1,
        dst=2,
        npairs=1,
        uuid=42
    )

    # Put the flow in node 1's message buffer
    put!(net[1], test_flow)

    # Run simulation for a short time
    run(sim, 2.0)

    # Check if a QDatagram was created and sent to node 2
    mb1 = messagebuffer(net, 1)
    qdatagram = query(mb1, QDatagram, ❓, ❓, ❓, ❓, ❓, ❓)
    @test collect(qdatagram.tag)[2:7] == [42, 1, 2, 0, 1, 0.0]
end

##

@testset "NetworkNodeController creating LinkLevelRequest" begin
    # Create registers with a few qubits each
    registers = [Register(5) for _ in 1:2]

    # Create network with registers
    net = RegisterNet(registers)

    # Get simulation from network
    sim = get_time_tracker(net)

    # Create NetworkNodeController at node 1
    network_controller = NetworkNodeController(sim, net, 1)
    @process network_controller()

    # Create a test QDatagram (from node 1 to node 2)
    test_qdatagram = QDatagram(
        flow_uuid=42,
        flow_src=1,
        flow_dst=2,
        correction=0,
        seq_num=1,
        start_time=0.0
    )

    run(sim, 1.0)

    # Put the QDatagram in node 1's message buffer
    put!(net[1], test_qdatagram)

    # Run simulation for a short time
    run(sim, 2.0)

    # Check if a LinkLevelRequest was created at node 1
    mb1 = messagebuffer(net, 1)
    link_request = query(mb1, LinkLevelRequest, ❓, ❓, ❓)
    @test !isnothing(link_request)
    @test collect(link_request.tag)[2:3] == [42, 1]  # Check flow_uuid and seq_num
end

##

@testset "LinkController responding to LinkLevelRequest with LinkLevelReply" begin
    # Create registers with a few qubits each
    registers = [Register(5) for _ in 1:2]

    # Create network with registers
    net = RegisterNet(registers)

    # Get simulation from network
    sim = get_time_tracker(net)

    # Create LinkController between nodes 1 and 2
    link_controller = LinkController(
        sim=sim,
        net=net,
        nodeA=1,
        nodeB=2
    )
    @process link_controller()

    # Create a test LinkLevelRequest
    test_request = LinkLevelRequest(
        flow_uuid=42,
        seq_num=1,
        remote_node=2
    )

    # Put the LinkLevelRequest in node 1's message buffer
    put!(net[1], test_request)

    # Run simulation to allow LinkController to process
    run(sim, 3.0)

    # Check if a LinkLevelReply was created at node 1 or node 2
    mb1 = messagebuffer(net, 1)
    mb2 = messagebuffer(net, 2)

    link_reply1 = query(mb1, LinkLevelReply, ❓, ❓, ❓)
    link_reply2 = query(mb2, LinkLevelReply, ❓, ❓, ❓)
    link_reply_at_destination1 = query(mb1, LinkLevelReplyAtHop, ❓, ❓, ❓)
    link_reply_at_destination2 = query(mb2, LinkLevelReplyAtHop, ❓, ❓, ❓)

    # The reply should be in one of the message buffers
    @test !isnothing(link_reply1) && isnothing(link_reply2)
    @test isnothing(link_reply_at_destination1) && !isnothing(link_reply_at_destination2)
    @test link_reply1.tag[2] == 42  # flow_uuid
    @test link_reply1.tag[3] == 1   # seq_num
    @test link_reply_at_destination2.tag[2] == 42  # flow_uuid
    @test link_reply_at_destination2.tag[3] == 1   # seq_num
end

##

@testset "LinkController responding to LinkLevelRequest and NetworkNodeController forwarding QDatagrams" begin
    # Create registers with a few qubits each
    registers = [Register(5) for _ in 1:3]  # Two registers for two nodes

    # Create network with registers
    net = RegisterNet(registers)

    # Get simulation from network
    sim = get_time_tracker(net)

    # Create NetworkNodeController at node 1
    network_controller = NetworkNodeController(sim, net, 1)
    @process network_controller()

    # Create LinkController between nodes 1 and 2
    link_controller = LinkController(
        sim=sim,
        net=net,
        nodeA=1,
        nodeB=2
    )
    @process link_controller()

    # Create a test QDatagram (from node 1 to node 2)
    test_qdatagram = QDatagram(
        flow_uuid=42,
        flow_src=1,
        flow_dst=3,
        correction=0,
        seq_num=1,
        start_time=0.0
    )

    # Put the QDatagram in node 1's message buffer
    put!(net[1], test_qdatagram)

    # Run simulation for a longer time to allow LinkController to process
    run(sim, 5.0)

    # Check if the QDatagram was forwarded to node 2
    mb2 = messagebuffer(net, 2)
    forwarded_qdatagram = query(mb2, QDatagram, 42, 1, 3, 0, 1, ❓)
    @test !isnothing(forwarded_qdatagram)
end

##

@testset "Complete QTCP protocol flow" begin
    # Create registers with a few qubits each
    registers = [Register(5) for _ in 1:5]

    # Create network with registers
    net = RegisterNet(registers; classical_delay=1e-6)

    # Get simulation from network
    sim = get_time_tracker(net)

    # Create EndNodeController at source (node 1) and destination (node 3)
    source_controller = EndNodeController(sim, net, 1)
    dest_controller = EndNodeController(sim, net, 5)
    @process source_controller()
    @process dest_controller()

    # Create NetworkNodeController at all nodes
    for node in 1:5
        network_controller = NetworkNodeController(sim, net, node)
        @process network_controller()
    end

    # Create LinkControllers for each link
    for edge in edges(net)
        link_controller = LinkController(
            sim=sim,
            net=net,
            nodeA=edge.src,
            nodeB=edge.dst
        )
        @process link_controller()
    end

    # Create a test flow from node 1 to node 5
    test_flow = Flow(
        src=1,
        dst=5,
        npairs=4,
        uuid=99
    )

    # Put the flow in node 1's message buffer
    put!(net[1], test_flow)

    # Run simulation to allow the complete protocol to execute
    run(sim, 1000.0)

    # Check if QDatagramSuccess messages were received at the source
    mb1 = messagebuffer(net, 1)
    mb2 = messagebuffer(net, 2)
    mb3 = messagebuffer(net, 3)
    mb4 = messagebuffer(net, 4)
    mb5 = messagebuffer(net, 5)

    @test isempty(mb2.buffer)
    @test isempty(mb3.buffer)
    @test isempty(mb4.buffer)
    for i in 1:4
        @test !isnothing(querydelete!(mb1, QTCPPairBegin, ❓, ❓, ❓, ❓, ❓, ❓))
        @test !isnothing(querydelete!(mb5, QTCPPairEnd, ❓, ❓, ❓, ❓, ❓, ❓))
    end
    @test isempty(mb1.buffer)
    @test isempty(mb5.buffer)
end

##

@testset "Concurrent flows on a grid stay correctly matched" begin
    graph = grid([3, 3])
    sim, net = setup_qtcp_network(graph, 10; classical_delay=1e-6, end_nodes=[1, 3, 7, 9])

    put!(net[1], Flow(src=1, dst=3, npairs=2, uuid=101))
    put!(net[7], Flow(src=7, dst=9, npairs=2, uuid=202))

    run(sim, 200.0)

    mb1 = messagebuffer(net, 1)
    mb3 = messagebuffer(net, 3)
    mb7 = messagebuffer(net, 7)
    mb9 = messagebuffer(net, 9)

    @test count_matching_tags!(mb1, QTCPPairBegin, 101, ❓, ❓, ❓, ❓, ❓) == 2
    @test count_matching_tags!(mb3, QTCPPairEnd, 101, ❓, ❓, ❓, ❓, ❓) == 2
    @test count_matching_tags!(mb7, QTCPPairBegin, 202, ❓, ❓, ❓, ❓, ❓) == 2
    @test count_matching_tags!(mb9, QTCPPairEnd, 202, ❓, ❓, ❓, ❓, ❓) == 2
end

##

@testset "Concurrent flows on the same repeater chain stay correctly matched" begin
    graph = grid([5])
    sim, net = setup_qtcp_network(graph, 12; classical_delay=1e-6, end_nodes=[1, 2, 4, 5])

    put!(net[1], Flow(src=1, dst=5, npairs=2, uuid=301))
    put!(net[2], Flow(src=2, dst=4, npairs=2, uuid=302))

    run(sim, 250.0)

    mb1 = messagebuffer(net, 1)
    mb2 = messagebuffer(net, 2)
    mb4 = messagebuffer(net, 4)
    mb5 = messagebuffer(net, 5)

    @test count_matching_tags!(mb1, QTCPPairBegin, 301, ❓, ❓, ❓, ❓, ❓) == 2
    @test count_matching_tags!(mb5, QTCPPairEnd, 301, ❓, ❓, ❓, ❓, ❓) == 2
    @test count_matching_tags!(mb2, QTCPPairBegin, 302, ❓, ❓, ❓, ❓, ❓) == 2
    @test count_matching_tags!(mb4, QTCPPairEnd, 302, ❓, ❓, ❓, ❓, ❓) == 2
end

##

@testset "qTCP protocol displays expose protocol-specific summaries" begin
    net = RegisterNet([Register(6), Register(6), Register(6)]; name="qtcp-display-net", names=["n1", "n2", "n3"])
    sim = get_time_tracker(net)

    put!(net[1], Flow(src=1, dst=3, npairs=2, uuid=11))
    put!(net[1], QDatagram(flow_uuid=11, flow_src=1, flow_dst=3, correction=0, seq_num=1, start_time=0.0))
    put!(net[1], QuantumSavory.ProtocolZoo.QTCP.QDatagramSuccess(flow_uuid=11, seq_num=1, start_time=0.0))
    put!(net[1], LinkLevelReplyAtSource(flow_uuid=11, seq_num=1, memory_slot=2))
    put!(net[1], QTCPPairBegin(flow_uuid=11, flow_src=1, flow_dst=3, seq_num=1, memory_slot=2, start_time=0.0))

    put!(net[2], QDatagram(flow_uuid=21, flow_src=1, flow_dst=3, correction=0, seq_num=4, start_time=1.0))
    put!(net[2], LinkLevelReply(flow_uuid=21, seq_num=4, memory_slot=1))
    put!(net[2], LinkLevelReplyAtHop(flow_uuid=21, seq_num=4, memory_slot=5))

    put!(net[1], LinkLevelRequest(flow_uuid=33, seq_num=1, remote_node=2))
    put!(net[1], LinkLevelReply(flow_uuid=33, seq_num=1, memory_slot=3))
    put!(net[2], LinkLevelRequest(flow_uuid=33, seq_num=1, remote_node=1))
    put!(net[2], LinkLevelReplyAtHop(flow_uuid=33, seq_num=1, memory_slot=4))

    end_node = EndNodeController(sim, net, 1)
    network_node = NetworkNodeController(sim, net, 2)
    link = LinkController(sim, net, 1, 2)

    end_html = repr(MIME"text/html"(), end_node)
    network_html = repr(MIME"text/html"(), network_node)
    link_html = repr(MIME"text/html"(), link)

    @test occursin("EndNodeController", end_html)
    @test occursin("node 1", end_html)
    @test occursin("Flow", end_html)
    @test occursin("<table>", end_html)
    @test !occursin("quantumsavory_protocol_unknown", end_html)

    @test occursin("NetworkNodeController", network_html)
    @test occursin("node 2", network_html)
    @test occursin("Degree", network_html)
    @test occursin("Inferred next hops", network_html)
    @test !occursin("quantumsavory_protocol_unknown", network_html)

    @test occursin("LinkController", link_html)
    @test occursin("endpoints 1 and 2", link_html)
    @test occursin("LinkLevelRequest", link_html)
    @test occursin("Slots", link_html)
    @test !occursin("quantumsavory_protocol_unknown", link_html)

    end_text = repr(end_node)
    network_text = repr(network_node)
    link_text = repr(link)
    @test occursin("EndNodeController", end_text)
    @test occursin("NetworkNodeController", network_text)
    @test occursin("LinkController", link_text)
end

##

end
