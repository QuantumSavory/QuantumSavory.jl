using Test
using QuantumSavory
using Gabs
using CairoMakie
import QuantumSavory: Register, Qubit, QuantumOpticsRepr, initialize!

@testset "Rich state show — PNG" begin

    @testset "1-qubit QOB PNG" begin
        reg = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!(reg[1], X₁)
        sr  = QuantumSavory.stateof(reg[1])
        buf = IOBuffer()
        @test_nowarn show(buf, MIME"image/png"(), sr)
        @test position(buf) > 0
    end

    @testset "2-qubit entangled QOB PNG" begin
        left  = Register([Qubit()], [QuantumOpticsRepr()])
        right = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!((left[1], right[1]), X₁⊗Z₁ + Z₁⊗X₁)
        sr  = QuantumSavory.stateof(left[1])
        buf = IOBuffer()
        @test_nowarn show(buf, MIME"image/png"(), sr)
        @test position(buf) > 0
    end

    @testset "QuantumClifford PNG (existing path)" begin
        reg = Register([Qubit(), Qubit()])
        initialize!((reg[1], reg[2]), StabilizerState("XX ZZ"))
        sr  = QuantumSavory.stateof(reg[1])
        buf = IOBuffer()
        @test_nowarn show(buf, MIME"image/png"(), sr)
        @test position(buf) > 0
    end

    @testset "Bloch vector helper — X eigenstate" begin
        reg   = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!(reg[1], X₁)
        state = QuantumSavory.quantumstate(QuantumSavory.stateof(reg[1]))
        rho   = QuantumSavory._dense_density_matrix(state)
        pq    = QuantumSavory._pauli_expectations_from_density_matrix(rho)
        @test abs(pq[1][2] - 1.0) < 1e-8   # ⟨X⟩ ≈ +1
        @test abs(pq[3][2])       < 1e-8   # ⟨Z⟩ ≈  0
    end


reg1 = Register([Qumode()], [GabsRepr(QuadBlockBasis)])
initialize!(reg1[1], SqueezedState(0.8))
apply!(reg1[1], DisplaceOp(0.6 - 0.4im))
out = IOBuffer(); show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


reg2 = Register([Qumode(), Qumode()], [GabsRepr(QuadBlockBasis), GabsRepr(QuadBlockBasis)])
initialize!(reg2[1:2], TwoSqueezedState(0.45))
out = IOBuffer(); show(out, MIME"image/png"(), QuantumSavory.stateof(reg2[1]))

end
