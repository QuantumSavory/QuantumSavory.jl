using Test
using QuantumSavory
using CairoMakie

@testset "show Gabs image/png" begin
    CairoMakie.activate!()

    reg = Register(
        fill(Qumode(), 2),
        fill(GabsRepr(QuantumSavory.Gabs.QuadBlockBasis), 2),
    )
    initialize!(reg[1:2], TwoSqueezedState(0.45))
    apply!(reg[1:2], BeamSplitterOp(1 / 2))

    out = IOBuffer()
    show(out, MIME"image/png"(), QuantumSavory.stateof(reg[1]))
    @test length(take!(out)) > 1000
end
