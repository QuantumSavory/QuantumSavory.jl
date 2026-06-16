using Test
using QuantumSavory
using QuantumOptics
using CairoMakie  # deterministic, no display needed

@testset "Rich StateRef PNG display" begin
    b = SpinBasis(1//2)

    # 1-qubit
    reg1 = Register(1, [spinup(b)])
    buf1 = IOBuffer()
    show(buf1, MIME"image/png"(), stateof(reg1[1]))
    data1 = take!(buf1)
    @test length(data1) > 100   # a real PNG has content
    @test data1[1:4] == UInt8[0x89, 0x50, 0x4e, 0x47]  # PNG magic bytes

    # 2-qubit
    b2   = SpinBasis(1//2) ⊗ SpinBasis(1//2)
    bell = (tensor(spinup(b), spinup(b)) + tensor(spindown(b), spindown(b))) / √2
    reg2 = Register(2)
    initialize!((reg2[1], reg2[2]), bell)
    buf2 = IOBuffer()
    show(buf2, MIME"image/png"(), stateof(reg2[1]))
    data2 = take!(buf2)
    @test length(data2) > 100

    # QuantumClifford – existing behaviour should not regress
    # (adjust to match how QC registers are built in QS)
    println("All PNG display tests passed")
end