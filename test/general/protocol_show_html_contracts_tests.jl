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

    @testset "BellPairSampler HTML handles empty and populated logs" begin
        empty_sampler = BellPairSampler(sim=sim, net=net, nodeA=1, nodeB=2)
        empty_html = repr(MIME"text/html"(), empty_sampler)

        @test occursin("BellPairSampler", empty_html)
        @test occursin("Sampled pairs", empty_html)
        @test occursin(">0<", empty_html)
        @test !occursin("NaN", empty_html)

        logged_sampler = BellPairSampler(
            sim=sim,
            net=net,
            nodeA=1,
            nodeB=2,
            _log=[
                (t=1.0, zz=1.0, xx=1.0, yy=-1.0, fidelity=1.0),
                (t=3.0, zz=0.8, xx=0.6, yy=-0.4, fidelity=0.7),
            ],
        )
        logged_html = repr(MIME"text/html"(), logged_sampler)

        @test occursin("Average Bell fidelity estimate", logged_html)
        @test occursin(">0.85<", logged_html)
        @test occursin("Average stabilizers ZZ | XX | YY", logged_html)
        @test occursin("0.9 | 0.8 | -0.7", logged_html)
        @test occursin("Fidelity", logged_html)
    end
end
