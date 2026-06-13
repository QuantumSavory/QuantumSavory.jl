using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo.QTCP: QDatagramSuccess  # not exported from QTCP
using Graphs

@testset "qTCP protocol show summaries" begin

# 3-node chain network 1 - 2 - 3 (vector-form RegisterNet builds a grid([3]) chain)
net = RegisterNet([Register(5) for _ in 1:3]; names=["n1", "n2", "n3"])
sim = get_time_tracker(net)

end_node = EndNodeController(sim, net, 1)
network_node = NetworkNodeController(sim, net, 2)
link = LinkController(sim, net, 1, 2)

# deterministically populate message buffers (no simulation run -> platform/thread stable)
mb1 = messagebuffer(net, 1)
put!(mb1, Flow(src=1, dst=3, npairs=2, uuid=42))
put!(mb1, QDatagram(flow_uuid=42, flow_src=1, flow_dst=3, correction=0, seq_num=1, start_time=0.0))
put!(mb1, QDatagramSuccess(flow_uuid=42, seq_num=1, start_time=0.0))
put!(mb1, QTCPPairBegin(flow_uuid=42, flow_src=1, flow_dst=3, seq_num=1, memory_slot=1, start_time=0.0))
put!(mb1, LinkLevelRequest(flow_uuid=42, seq_num=1, remote_node=2))

mb2 = messagebuffer(net, 2)
put!(mb2, QDatagram(flow_uuid=42, flow_src=1, flow_dst=3, correction=0, seq_num=1, start_time=0.0))
put!(mb2, LinkLevelReply(flow_uuid=42, seq_num=1, memory_slot=2))

@testset "text show includes node/endpoint info" begin
    et = sprint(show, end_node)
    @test occursin("EndNodeController", et)
    @test occursin("node 1", et)

    nt = sprint(show, network_node)
    @test occursin("NetworkNodeController", nt)
    @test occursin("node 2", nt)

    lt = sprint(show, link)
    @test occursin("LinkController", lt)
    @test occursin("node 1", lt)
    @test occursin("node 2", lt)
end

@testset "EndNodeController HTML" begin
    h = repr(MIME"text/html"(), end_node)
    @test occursin("EndNodeController", h)
    @test !occursin("quantumsavory_protocol_unknown", h)
    @test occursin("quantumsavory_protocol_qtcp_endnode", h)
    @test occursin("<table", h)
    @test occursin("Flow", h)
    @test occursin("QDatagram", h)
    @test occursin("n1", h)            # register label via compactstr
end

@testset "NetworkNodeController HTML" begin
    h = repr(MIME"text/html"(), network_node)
    @test occursin("NetworkNodeController", h)
    @test !occursin("quantumsavory_protocol_unknown", h)
    @test occursin("quantumsavory_protocol_qtcp_networknode", h)
    @test occursin("Neighbors", h)
    @test occursin("1, 3", h)          # node 2 on a chain neighbors 1 and 3
    @test occursin("next hop", h)      # routing table header
end

@testset "LinkController HTML" begin
    h = repr(MIME"text/html"(), link)
    @test occursin("LinkController", h)
    @test !occursin("quantumsavory_protocol_unknown", h)
    @test occursin("quantumsavory_protocol_qtcp_link", h)
    @test occursin("node 1", h)
    @test occursin("node 2", h)
    @test occursin("Endpoints", h)
end

@testset "message-count helper" begin
    c = QuantumSavory.ProtocolZoo._qtcp_message_counts(QuantumSavory.peektags(messagebuffer(net, 1)))
    @test c.Flow == 1
    @test c.QDatagram == 1
    @test c.QDatagramSuccess == 1
    @test c.QTCPPairBegin == 1
    @test c.LinkLevelRequest == 1
    @test c.LinkLevelReply == 0
end

@testset "empty buffers still render protocol-specific HTML" begin
    net2 = RegisterNet([Register(2), Register(2)])
    sim2 = get_time_tracker(net2)
    for prot in (EndNodeController(sim2, net2, 1), NetworkNodeController(sim2, net2, 1), LinkController(sim2, net2, 1, 2))
        h = repr(MIME"text/html"(), prot)
        @test !occursin("quantumsavory_protocol_unknown", h)
    end
end

end
