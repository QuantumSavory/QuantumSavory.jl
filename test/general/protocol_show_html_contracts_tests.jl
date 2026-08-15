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

    @testset "LinkController HTML summarizes request timing" begin
        link_controller = LinkController(sim, net, 1, 2)
        empty_html = repr(MIME"text/html"(), link_controller)

        @test occursin("quantumsavory_protocol_link_controller", empty_html)
        @test occursin("quantumsavory_protocol_typename\">LinkController", empty_html)
        @test occursin("quantumsavory_protocol_entangler", empty_html)
        @test occursin("left", empty_html)
        @test occursin("right", empty_html)
        @test occursin("No samples", empty_html)
        @test !occursin("NaN", empty_html)

        append!(link_controller._log, [
            (originator_node=1, arrival_time=1.0, sojourn_time=2.0),
            (originator_node=2, arrival_time=2.0, sojourn_time=4.0),
            (originator_node=1, arrival_time=5.0, sojourn_time=nothing),
            (originator_node=2, arrival_time=8.0, sojourn_time=6.0),
            (originator_node=1, arrival_time=9.0, sojourn_time=8.0),
            (originator_node=2, arrival_time=14.0, sojourn_time=10.0),
        ])
        populated_html = repr(MIME"text/html"(), link_controller)

        @test occursin("Mean interarrival time", populated_html)
        @test occursin("Median interarrival time", populated_html)
        @test occursin(">4.0<", populated_html)
        @test occursin(">6.0<", populated_html)
        @test occursin("Completed requests", populated_html)
        @test occursin("Pending requests", populated_html)
        @test occursin("Originator node", populated_html)
        @test occursin("Arrival time", populated_html)
        @test occursin("Sojourn time", populated_html)
    end
end
