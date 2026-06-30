using Test
using QuantumSavory
using QuantumClifford: @S_str, MixedDestabilizer
using Gabs
using QuantumSavory.ProtocolZoo
using Gabs

@testset "show text/html" begin

#out = stdout
out = IOBuffer()

reg = Register([Qubit(), Qumode()], [CliffordRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])

initialize!(reg[1], X1)

show(out, MIME"text/html"(), reg[1])
show(out, MIME"text/html"(), reg[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg[1]))

reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

show(out, MIME"text/html"(), reg1[1])
show(out, MIME"text/html"(), reg2[2])
show(out, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))


@testset "Rich state show — text and HTML" begin

    @testset "1-qubit QOB text" begin
        reg = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!(reg[1], X₁)
        sr  = QuantumSavory.stateof(reg[1])
        txt = sprint(show, sr)
        @test occursin("QuantumOpticsBase", txt)
        @test !occursin("does not support", txt)
        @test occursin("Purity", txt)
        @test occursin("⟨X⟩", txt)
    end

    @testset "1-qubit QOB HTML" begin
        reg  = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!(reg[1], X₁)
        sr   = QuantumSavory.stateof(reg[1])
        html = repr(MIME"text/html"(), sr)
        @test occursin("QuantumOpticsBase", html)
        @test !occursin("does not support", html)
        @test occursin("Purity", html)
        @test occursin("⟨X⟩", html)
    end

    @testset "2-qubit entangled QOB text" begin
        left  = Register([Qubit()], [QuantumOpticsRepr()])
        right = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!((left[1], right[1]), X₁⊗Z₁ + Z₁⊗X₁)
        sr  = QuantumSavory.stateof(left[1])
        txt = sprint(show, sr)
        @test occursin("QuantumOpticsBase", txt)
        @test !occursin("does not support", txt)
        @test occursin("Purity", txt)
    end

    @testset "2-qubit entangled QOB HTML" begin
        left  = Register([Qubit()], [QuantumOpticsRepr()])
        right = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!((left[1], right[1]), X₁⊗Z₁ + Z₁⊗X₁)
        sr   = QuantumSavory.stateof(left[1])
        html = repr(MIME"text/html"(), sr)
        @test occursin("QuantumOpticsBase", html)
        @test !occursin("does not support", html)
    end

    @testset "QuantumClifford text" begin
        reg = Register([Qubit(), Qubit()])
        initialize!((reg[1], reg[2]), MixedDestabilizer(S"XX ZZ"))
        sr  = QuantumSavory.stateof(reg[1])
        txt = sprint(show, sr)
        @test occursin("QuantumClifford", txt)
        @test !occursin("does not support", txt)
        @test occursin("stabilizer", lowercase(txt))
    end

    @testset "QuantumClifford HTML" begin
        reg  = Register([Qubit(), Qubit()])
        initialize!((reg[1], reg[2]), MixedDestabilizer(S"XX ZZ"))
        sr   = QuantumSavory.stateof(reg[1])
        html = repr(MIME"text/html"(), sr)
        @test occursin("QuantumClifford", html)
        @test !occursin("does not support", html)
    end

    @testset "helper functions" begin
        reg = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!(reg[1], X₁)
        sr    = QuantumSavory.stateof(reg[1])
        state = QuantumSavory.quantumstate(sr)

        dims = QuantumSavory._basis_dimensions(state)
        @test dims == [2]

        rho = QuantumSavory._dense_density_matrix(state)
        @test size(rho) == (2, 2)
        @test real(tr(rho)) ≈ 1.0 atol=1e-10

        p = QuantumSavory._purity(rho)
        @test 0.0 ≤ p ≤ 1.0 + 1e-10

        s = QuantumSavory._von_neumann_entropy(rho)
        @test s ≥ -1e-10

        pq = QuantumSavory._pauli_expectations_from_density_matrix(rho)
        @test length(pq) == 3
        @test sqrt(sum(x -> x[2]^2, pq)) ≤ 1.0 + 1e-10

        rows = QuantumSavory._top_probability_rows(state; topk=4)
        @test all(0 ≤ p ≤ 1 + 1e-10 for (_, p) in rows)
    end


reg1 = Register([Qumode()], [GabsRepr(QuadPairBasis)])
initialize!(reg1[1], CoherentState(0.2 - 0.5im))
apply!(reg1[1], DisplaceOp(0.6 - 0.4im))
html = sprint(show, MIME"text/html"(), QuantumSavory.stateof(reg1[1]))
@test !occursin("does not support rich visualization", html)


end

# ── Rich state display tests (Issue #401) ─────────────────────────────────────
using QuantumClifford: MixedDestabilizer, @S_str
import QuantumSavory: Register, Qubit, QuantumOpticsRepr

@testset "Rich state show — text and HTML" begin

    @testset "1-qubit QOB text" begin
        reg = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!(reg[1], X₁)
        sr  = QuantumSavory.stateof(reg[1])
        txt = sprint(show, sr)
        @test occursin("QuantumOpticsBase", txt)
        @test !occursin("does not support", txt)
        @test occursin("Purity", txt)
        @test occursin("⟨X⟩", txt)
    end

    @testset "1-qubit QOB HTML" begin
        reg  = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!(reg[1], X₁)
        sr   = QuantumSavory.stateof(reg[1])
        html = repr(MIME"text/html"(), sr)
        @test occursin("QuantumOpticsBase", html)
        @test !occursin("does not support", html)
        @test occursin("Purity", html)
        @test occursin("⟨X⟩", html)
    end

    @testset "2-qubit entangled QOB text" begin
        left  = Register([Qubit()], [QuantumOpticsRepr()])
        right = Register([Qubit()], [QuantumOpticsRepr()])
        initialize!((left[1], right[1]), X₁⊗Z₁ + Z₁⊗X₁)
        sr  = QuantumSavory.stateof(left[1])
        txt = sprint(show, sr)
        @test occursin("QuantumOpticsBase", txt)
        @test !occursin("does not support", txt)
    end

    @testset "QuantumClifford text" begin
        reg = Register([Qubit(), Qubit()])
        initialize!((reg[1], reg[2]), MixedDestabilizer(S"XX ZZ"))
        sr  = QuantumSavory.stateof(reg[1])
        txt = sprint(show, sr)
        @test occursin("QuantumClifford", txt)
        @test !occursin("does not support", txt)
    end

    @testset "QuantumClifford HTML" begin
        reg  = Register([Qubit(), Qubit()])
        initialize!((reg[1], reg[2]), MixedDestabilizer(S"XX ZZ"))
        sr   = QuantumSavory.stateof(reg[1])
        html = repr(MIME"text/html"(), sr)
        @test occursin("QuantumClifford", html)
        @test !occursin("does not support", html)
    end

end
end
