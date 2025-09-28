@testitem "StatesZoo API" begin
using Test
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW
using QuantumOpticsBase
using LinearAlgebra

onlyon112 = if VERSION >= v"1.12.0-DEV.2047"
    [MultiplexedCascadedBellPair, MultiplexedCascadedBellPairW]
else
    []
end

onlyon112normed = if VERSION >= v"1.12.0-DEV.2047"
    [MultiplexedCascadedBellPair]
else
    []
end

_evalf(x::Number) = x
_evalf(x) = express(x)

for S in [BarrettKokBellPair, BarrettKokBellPairW,
    GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW,
    onlyon112...
    ] # TODO use some abstract supertype to automatically get all of these
    params = QuantumSavory.StatesZoo.stateparameters(S)
    paramdict = QuantumSavory.StatesZoo.stateparametersrange(S)
    state = S((paramdict[p].good for p in params)...)

    reg = Register(2)
    initialize!(reg[1:2], state)
    @test ! iszero(observable(reg[1:2], Z⊗Z))
    @test _evalf(tr(state)) ≈ tr(express(state))
end

for S in [BarrettKokBellPair, onlyon112normed...] # TODO use some abstract supertype
    params = QuantumSavory.StatesZoo.stateparameters(S)
    paramdict = QuantumSavory.StatesZoo.stateparametersrange(S)
    state = S((paramdict[p].good for p in params)...)
    @test tr(state) ≈ 1
end

end
