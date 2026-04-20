@testitem "StatesZoo DepolarizedBellPair" begin
using Test
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumOpticsBase
using QuantumClifford
using LinearAlgebra

# p-constructor and fidelity-constructor consistency
p = 0.7
F = (3p + 1) / 4
s_from_p = DepolarizedBellPair(p)
s_from_F = DepolarizedBellPair(F=F)
@test express(s_from_p) ≈ express(s_from_F)

# trace is 1 for any p
for p in [0.0, 0.5, 1.0]
    dm = express(DepolarizedBellPair(p))
    @test tr(dm) ≈ 1
end

# at p=1, pure Bell state: ⟨ZZ⟩ = 1
reg = Register(2)
initialize!(reg[1:2], DepolarizedBellPair(1.0))
@test observable(reg[1:2], QuantumSymbolics.Z⊗QuantumSymbolics.Z) ≈ 1
reg_c = Register(2, CliffordRepr())
initialize!(reg_c[1:2], DepolarizedBellPair(1.0))
@test observable(reg_c[1:2], QuantumSymbolics.Z⊗QuantumSymbolics.Z) ≈ 1

# at p=0, maximally mixed: density matrix = I/4
dm_mixed = express(DepolarizedBellPair(0.0))
@test dm_mixed.data ≈ LinearAlgebra.I / 4

# fidelity-to-p and p-to-fidelity roundtrip
for F in [0.25, 0.5, 0.75, 1.0]
    p_rt = (4F - 1) / 3
    @test (3p_rt + 1) / 4 ≈ F
    dm = express(DepolarizedBellPair(F=F))
    @test tr(dm) ≈ 1
end

end
