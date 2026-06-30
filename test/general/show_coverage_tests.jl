using Test
import QuantumSavory
import QuantumOptics: SpinBasis, spinup, spindown, tensor, DenseOperator
import LinearAlgebra: norm
import QuantumSavory: stateof, initialize!, quantumstate

@testset "Coverage: Operator-typed dispatch paths" begin
    b = SpinBasis(1//2)
    ρ = DenseOperator(b, ComplexF64[0.7 0; 0 0.3])
    reg = QuantumSavory.Register(1)
    initialize!(reg[1], ρ)

    txt = sprint(show, stateof(reg[1]))
    @test occursin("Purity", txt)

    html = repr(MIME"text/html"(), stateof(reg[1]))
    @test occursin("Purity", html)
end

@testset "Coverage: negative-imaginary complex formatting" begin
    # ψ = |0⟩ + (1+i)|1⟩ (unnormalized; normalization doesn't affect sign logic).
    # ρ01 = a*conj(b) = 1*(1-i) = 1-1im  -> re=1, im_=-1 (both nonzero) -> "-" branch
    # ρ10 = conj(ρ01) = 1+1im            -> re=1, im_=+1 (both nonzero) -> "+" branch
    # This forces _format_complex's sign = im_ >= 0 ? "+" : "-" to take both paths,
    # unlike a pure ±i superposition where the iszero(re) shortcut fires instead.
    b  = SpinBasis(1//2)
    ψ  = (spinup(b) + (1 + im) * spindown(b))
    ψ  = ψ / norm(ψ)
    reg = QuantumSavory.Register(1)
    initialize!(reg[1], ψ)

    txt = sprint(show, stateof(reg[1]))
    @test occursin("+", txt)
    @test occursin("-", txt)
end

@testset "Coverage: dense-display-suppressed branch (N > 128)" begin
    b  = SpinBasis(1//2)
    ψ8 = tensor([spinup(b) for _ in 1:8]...)
    reg8 = QuantumSavory.Register(8)
    initialize!(Tuple(reg8[i] for i in 1:8), ψ8)

    txt = sprint(show, stateof(reg8[1]))
    @test occursin("suppressed", txt)

    html = repr(MIME"text/html"(), stateof(reg8[1]))
    @test occursin("suppressed", html)

    sref  = stateof(reg8[1])
    qs    = quantumstate(sref)
    lines = QuantumSavory._stateref_summary_lines(qs, sref; topk=6)
    @test any(occursin("suppressed", l) for l in lines)
end

println("All coverage-gap tests passed ✓")
