using Test
using QuantumSavory
using Gabs

@testset "show Gabs Gaussian states" begin
    reg = Register(fill(Qumode(), 2), fill(GabsRepr(QuadBlockBasis), 2))
    initialize!(reg[1:2], TwoSqueezedState(0.45))
    apply!(reg[1:2], BeamSplitterOp(1 / 2))
    stateref = QuantumSavory.stateof(reg[1])

    @test stateref === QuantumSavory.stateof(reg[2])
    @test Gabs.nmodes(QuantumSavory.quantumstate(stateref)) == 2

    text = sprint(show, stateref)
    @test occursin("Gaussian state summary", text)
    @test occursin("Modes: 2", text)
    @test occursin("Basis: QuadBlockBasis", text)
    @test occursin("First moments", text)
    @test occursin("Covariance by mode", text)
    @test occursin("Max |inter-mode covariance|", text)

    html = repr(MIME"text/html"(), stateref)
    @test occursin("quantumsavory_gabs_state", html)
    @test occursin("Gaussian state", html)
    @test occursin("First moments", html)
    @test occursin("Covariance matrix", html)
    @test occursin("q1", html)
    @test occursin("p2", html)
    @test !occursin("does not support rich visualization", html)

    pair_reg = Register([Qumode()], [GabsRepr(QuadPairBasis)])
    initialize!(pair_reg[1], CoherentState(0.2 + 0.1im))
    pair_stateref = QuantumSavory.stateof(pair_reg[1])

    pair_text = sprint(show, pair_stateref)
    @test occursin("Basis: QuadPairBasis", pair_text)

    pair_html = repr(MIME"text/html"(), pair_stateref)
    @test occursin("Basis:</b> QuadPairBasis", pair_html)
    @test occursin("q1", pair_html)
    @test occursin("p1", pair_html)
end
