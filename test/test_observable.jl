@testitem "Observable" begin
using Test
using QuantumSavory

@testset "entangled observable" begin
    bell = StabilizerState("XX ZZ")
    # or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
    # however converting to stabilizer state for Clifford simulations
    # is not implemented (and can not be done efficiently).

    for rep in [QuantumOpticsRepr(), CliffordRepr()]
        a = Register(2,rep)
        initialize!(a[1:2], bell)
        @test observable(a[1:2], SProjector(bell)) ≈ 1.0
        @test observable(a[1:2], σˣ⊗σˣ) ≈ 1.0
        apply!(a[1], σʸ)
        @test observable(a[1:2], SProjector(bell)) ≈ 0.0 atol=1e-5
        @test observable(a[1:2], σˣ⊗σˣ) ≈ -1.0
    end
end

@testset "separable observable with order flipping" begin
    A = StabilizerState("X")
    B = StabilizerState("Z")
    AB = StabilizerState("XI IZ")
    BA = StabilizerState("ZI IX")

    for rep in [QuantumOpticsRepr(), CliffordRepr()]
        r1 = Register(2,rep)
        r2 = Register(2,rep)
        r12 = Register(2,rep)
        r21 = Register(2,rep)

        initialize!(r1[1], A)
        initialize!(r2[2], B)
        initialize!(r12[1:2], AB)
        initialize!((r21[2], r21[1]), BA)

        @test observable(r12[1:2], SProjector(AB)) ≈ 1.0
        if rep == CliffordRepr()
            @test_throws "entangled with other qubits" observable(r12[1], SProjector(A)) ≈ 1.0
        else
            @test observable(r12[1], SProjector(A)) ≈ 1.0
        end
        @test observable(r21[1:2], SProjector(AB)) ≈ 1.0
        @test_broken observable((r1[1], r2[2]), SProjector(AB)) ≈ 1.0
        @test observable(r1[1], SProjector(A)) ≈ 1.0
        @test observable(r2[2], SProjector(B)) ≈ 1.0
    end
end

end
