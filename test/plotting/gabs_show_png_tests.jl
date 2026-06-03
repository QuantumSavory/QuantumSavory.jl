using Test
using QuantumSavory
using Gabs
using CairoMakie

const GABS_QBLOCK = GabsRepr(QuadBlockBasis)
const PNG_MAGIC = UInt8[0x89, 0x50, 0x4e, 0x47]

function png_bytes(stateref)
    io = IOBuffer()
    show(io, MIME"image/png"(), stateref)
    return take!(io)
end

@testset "Gabs Gaussian state PNG display" begin
    @testset "one-mode coherent state" begin
        reg = Register([Qumode()], [GABS_QBLOCK])
        initialize!(reg[1], CoherentState(0.5 + 0.2im))
        png = png_bytes(QuantumSavory.stateof(reg[1]))
        @test length(png) > 1000
        @test png[1:4] == PNG_MAGIC
    end

    @testset "two-mode squeezed state" begin
        reg = Register(fill(Qumode(), 2), fill(GABS_QBLOCK, 2))
        initialize!(reg[1:2], TwoSqueezedState(0.45))
        png = png_bytes(QuantumSavory.stateof(reg[1]))
        @test length(png) > 1000
        @test png[1:4] == PNG_MAGIC
    end
end
