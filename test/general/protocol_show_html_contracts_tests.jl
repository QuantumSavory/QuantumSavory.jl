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
            _log=EntanglementConsumerLog(
                time=[2.0, 4.0],
                obs1=[1.0, 0.0],
                obs2=[0.5, -0.5],
            ),
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
end
