using Test
using QuantumSavory
using Gabs
using CairoMakie

@testset "Gabs Gaussian state PNG display" begin
    reg = Register(fill(Qumode(), 2), fill(GabsRepr(QuadBlockBasis), 2))
    initialize!(reg[1:2], TwoSqueezedState(0.45))
    out = IOBuffer()
    show(out, MIME"image/png"(), QuantumSavory.stateof(reg[1]))
    png = take!(out)
    @test length(png) > 1000
    @test startswith(png, UInt8[0x89, 0x50, 0x4e, 0x47]) # PNG magic
end
