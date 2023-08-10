using Test
using QuantumSavory

const bell = StabilizerState("XX ZZ")
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

for rep in [QuantumOpticsRepr(), CliffordRepr()]
    a = Register(2,rep)
    initialize!(a[1:2], bell)
    @test observable(a[1:2], SProjector(bell)) ≈ 1.0
    @test observable(a[1:2], σˣ⊗σˣ) ≈ 1.0
    apply!(a[1], σʸ)
    @test observable(a[1:2], SProjector(bell)) ≈ 0.0
    @test observable(a[1:2], σˣ⊗σˣ) ≈ -1.0
end
