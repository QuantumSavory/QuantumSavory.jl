using Test
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: AbstractProtocol, EntanglementCounterpart, EntanglementHistory,
    EntanglementUpdateX, EntanglementUpdateZ
using QuantumSavory.ProtocolZoo: EntanglementDelete

function assert_tag_surface_contract(value, expected_tag, expected_text)
    @test Tag(value) == expected_tag
    @test occursin(expected_text, sprint(show, value))
end

struct DummyProtocol <: AbstractProtocol
    sim::Simulation
end

@testset "ProtocolZoo surface contracts" begin
    @testset "protocol tag values round-trip through Tag and show" begin
        assert_tag_surface_contract(
            EntanglementCounterpart(2, 3),
            Tag(EntanglementCounterpart, 2, 3),
            "Entangled to 2.3",
        )
        assert_tag_surface_contract(
            EntanglementHistory(2, 3, 4, 5, 6),
            Tag(EntanglementHistory, 2, 3, 4, 5, 6),
            "Was entangled to 2.3",
        )
        assert_tag_surface_contract(
            EntanglementUpdateX(2, 3, 4, 5, 6, 2),
            Tag(EntanglementUpdateX, 2, 3, 4, 5, 6, 2),
            "apply correction Z2",
        )
        assert_tag_surface_contract(
            EntanglementUpdateZ(2, 3, 4, 5, 6, 1),
            Tag(EntanglementUpdateZ, 2, 3, 4, 5, 6, 1),
            "apply correction X1",
        )
        assert_tag_surface_contract(
            EntanglementDelete(2, 3, 4, 5),
            Tag(EntanglementDelete, 2, 3, 4, 5),
            "Deleted 2.3",
        )
    end

    @testset "QTCP control messages preserve their human-readable metadata" begin
        assert_tag_surface_contract(Flow(1, 5, 3, 42), Tag(Flow, 1, 5, 3, 42), "Flow `42` | 1")
        assert_tag_surface_contract(
            QTCPPairBegin(7, 1, 5, 2, 9, 1.5),
            Tag(QTCPPairBegin, 7, 1, 5, 2, 9, 1.5),
            "QTCPPairBegin `7.2`",
        )
        assert_tag_surface_contract(
            QTCPPairEnd(7, 1, 5, 2, 9, 1.5),
            Tag(QTCPPairEnd, 7, 1, 5, 2, 9, 1.5),
            "QTCPPairEnd `7.2`",
        )
        assert_tag_surface_contract(
            QDatagram(7, 1, 5, 3, 2, 1.5),
            Tag(QDatagram, 7, 1, 5, 3, 2, 1.5),
            "correction 3",
        )
        assert_tag_surface_contract(
            QuantumSavory.ProtocolZoo.QTCP.QDatagramSuccess(7, 2, 1.5),
            Tag(QuantumSavory.ProtocolZoo.QTCP.QDatagramSuccess, 7, 2, 1.5),
            "QDatagramSuccess `7.2`",
        )
        assert_tag_surface_contract(
            LinkLevelRequest(7, 2, 5),
            Tag(LinkLevelRequest, 7, 2, 5),
            "remote node 5",
        )
        assert_tag_surface_contract(
            LinkLevelReply(7, 2, 9),
            Tag(LinkLevelReply, 7, 2, 9),
            "memory slot 9",
        )
        assert_tag_surface_contract(
            LinkLevelReplyAtSource(7, 2, 9),
            Tag(LinkLevelReplyAtSource, 7, 2, 9),
            "memory slot 9",
        )
        assert_tag_surface_contract(
            LinkLevelReplyAtHop(7, 2, 9),
            Tag(LinkLevelReplyAtHop, 7, 2, 9),
            "memory slot 9",
        )
    end

    @testset "HTML rendering reports protocol-specific summaries" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)

        fallback_html = sprint(show, MIME"text/html"(), DummyProtocol(sim))
        @test occursin("DummyProtocol", fallback_html)
        @test occursin("does not support rich visualization in HTML", fallback_html)

        entangler = EntanglerProt(sim, net, 1, 2; success_prob=0.25)
        entangler_html = sprint(show, MIME"text/html"(), entangler)
        @test occursin("EntanglerProt", entangler_html)
        @test occursin("0.25", entangler_html)
        @test occursin("4.0", entangler_html)

        consumer = EntanglementConsumer(sim, net, 1, 2)
        push!(consumer._log, (1.0, 1.0, -1.0))
        push!(consumer._log, (3.0, -1.0, 1.0))
        consumer_html = sprint(show, MIME"text/html"(), consumer)
        @test occursin("Consumed pairs", consumer_html)
        @test occursin(">2<", consumer_html)
        @test occursin("1.5", consumer_html)
        @test occursin("0.0 | 0.0", consumer_html)
    end

    @testset "QTCP shorthand constructors inherit the network simulation" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)

        @test get_time_tracker(EndNodeController(net, 1)) === sim
        @test get_time_tracker(NetworkNodeController(net, 1)) === sim
        @test get_time_tracker(LinkController(net, 1, 2)) === sim
    end
end
