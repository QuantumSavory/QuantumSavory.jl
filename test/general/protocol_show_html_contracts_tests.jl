using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo

struct DummyProtocol <: QuantumSavory.ProtocolZoo.AbstractProtocol end

@testset "Protocol HTML rendering" begin
    net = RegisterNet([Register(2), Register(2)]; name="line", names=["left", "right"])
    sim = get_time_tracker(net)

    @testset "Unknown protocols render a helpful fallback" begin
        html = repr(MIME"text/html"(), DummyProtocol())

        @test occursin("DummyProtocol", html)
        @test occursin("quantumsavory_protocol_unknown", html)
        @test occursin("does not support rich visualization", html)
    end

    @testset "EntanglerProt HTML includes endpoints and timing summary" begin
        prot = EntanglerProt(sim, net, 1, 2; success_prob=0.25)
        html = repr(MIME"text/html"(), prot)

        @test occursin("EntanglerProt", html)
        @test occursin("left", html)
        @test occursin("right", html)
        @test occursin("Success probability per attempt", html)
        @test occursin(">0.25<", html)
        @test occursin("Mean time to generate a state", html)
        @test occursin(">4.0<", html)
    end

    @testset "EntanglementConsumer HTML handles empty and populated logs" begin
        empty_consumer = EntanglementConsumer(sim=sim, net=net, nodeA=1, nodeB=2)
        empty_html = repr(MIME"text/html"(), empty_consumer)

        @test occursin("Consumed pairs", empty_html)
        @test occursin(">0<", empty_html)
        @test occursin("NaN", empty_html)

        logged_consumer = EntanglementConsumer(
            sim=sim,
            net=net,
            nodeA=1,
            nodeB=2,
            _log=[
                (t=2.0, obs1=1.0, obs2=0.5),
                (t=4.0, obs1=0.0, obs2=-0.5),
            ],
        )
        logged_html = repr(MIME"text/html"(), logged_consumer)

        @test occursin("Consumed pairs", logged_html)
        @test occursin(">2<", logged_html)
        @test occursin("Total time", logged_html)
        @test occursin(">4.0<", logged_html)
        @test occursin("Average observable of ZZ and XX", logged_html)
        @test occursin("0.5 | 0.0", logged_html)
        @test occursin("Observable 1", logged_html)
        @test occursin("Observable 2", logged_html)
    end

    @testset "QTCP controllers render protocol-specific summaries" begin
        qtcp_net = RegisterNet(
            [Register(3), Register(3), Register(3)];
            name="qtcp-line",
            names=["source", "repeater", "sink"],
        )
        qtcp_sim = get_time_tracker(qtcp_net)

        put!(qtcp_net[1], Flow(src=1, dst=3, npairs=2, uuid=7))
        put!(qtcp_net[1], QTCPPairBegin(flow_uuid=7, flow_src=1, flow_dst=3, seq_num=1, memory_slot=1, start_time=0.0))
        put!(qtcp_net[2], QDatagram(flow_uuid=7, flow_src=1, flow_dst=3, correction=0, seq_num=1, start_time=0.0))
        put!(qtcp_net[1], LinkLevelRequest(flow_uuid=7, seq_num=1, remote_node=2))

        end_controller = EndNodeController(qtcp_sim, qtcp_net, 1)
        end_text = sprint(show, end_controller)
        end_html = repr(MIME"text/html"(), end_controller)

        @test occursin("EndNodeController", end_text)
        @test occursin("node: 1", end_text)
        @test occursin("Flow=1", end_text)
        @test occursin("completed pair tags", end_text)
        @test occursin("quantumsavory_protocol_qtcp_end_node", end_html)
        @test occursin("Flow", end_html)
        @test occursin("QTCPPairBegin", end_html)
        @test !occursin("quantumsavory_protocol_unknown", end_html)

        network_controller = NetworkNodeController(qtcp_sim, qtcp_net, 2)
        network_text = sprint(show, network_controller)
        network_html = repr(MIME"text/html"(), network_controller)

        @test occursin("NetworkNodeController", network_text)
        @test occursin("neighbors", network_text)
        @test occursin("QDatagram=1", network_text)
        @test occursin("Visible QDatagram routes", network_html)
        @test occursin("7.1", network_html)
        @test occursin("Next hop", network_html)
        @test !occursin("quantumsavory_protocol_unknown", network_html)

        link_controller = LinkController(qtcp_sim, qtcp_net, 1, 2)
        link_text = sprint(show, link_controller)
        link_html = repr(MIME"text/html"(), link_controller)

        @test occursin("LinkController", link_text)
        @test occursin("endpoints", link_text)
        @test occursin("LinkLevelRequest=1", link_text)
        @test occursin("Endpoint registers", link_html)
        @test occursin("Endpoint qTCP message buffers", link_html)
        @test occursin("LinkLevelRequest", link_html)
        @test !occursin("quantumsavory_protocol_unknown", link_html)
    end
end
