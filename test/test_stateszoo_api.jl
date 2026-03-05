@testitem "StatesZoo API" begin
using Test
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW
using QuantumOpticsBase
using LinearAlgebra

_evalf(x::Number) = x
_evalf(x) = express(x)

for S in [BarrettKokBellPair, BarrettKokBellPairW,
    GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW,
    ] # TODO use some abstract supertype to automatically get all of these
    params = QuantumSavory.StatesZoo.stateparameters(S)
    paramdict = QuantumSavory.StatesZoo.stateparametersrange(S)
    state = S((paramdict[p].good for p in params)...)

    reg = Register(2)
    initialize!(reg[1:2], state)
    @test ! iszero(observable(reg[1:2], Z⊗Z))
    @test _evalf(tr(state)) ≈ tr(express(state))
end

for S in [BarrettKokBellPair] # TODO use some abstract supertype
    params = QuantumSavory.StatesZoo.stateparameters(S)
    paramdict = QuantumSavory.StatesZoo.stateparametersrange(S)
    state = S((paramdict[p].good for p in params)...)
    @test tr(state) ≈ 1
end

end
