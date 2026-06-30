using Test
import QuantumSavory
import QuantumOptics: SpinBasis, spinup, tensor
import QuantumSavory: stateof, initialize!, quantumstate
using CairoMakie

@testset "Coverage: stateshowimage isempty(rows) fallback" begin
    b  = SpinBasis(1//2)
    ψ8 = tensor([spinup(b) for _ in 1:8]...)
    reg8 = QuantumSavory.Register(8)
    initialize!(Tuple(reg8[i] for i in 1:8), ψ8)

    sref = stateof(reg8[1])
    qs   = quantumstate(sref)

    fig = Figure()
    ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    ext.stateshowimage(fig[1,1], qs, sref)

    buf = IOBuffer()
    show(buf, MIME"image/png"(), fig)
    data = take!(buf)
    @test length(data) > 100
    @test data[1:4] == UInt8[0x89, 0x50, 0x4e, 0x47]
end

println("PNG coverage tests passed ✓")
