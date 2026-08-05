using Test
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW
using QuantumOpticsBase
using LinearAlgebra

@testset "StatesZoo API" begin

_evalf(x::Number) = x
_evalf(x) = express(x)

for S in [BarrettKokBellPair, BarrettKokBellPairW,
    GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW,
    DepolarizedBellPair
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

@testset "Genqo wrapper constructor surface" begin
    @test stateparameters(GenqoMultiplexedCascadedBellPairW) == (:ηᵇ, :ηᵈ, :ηᵗ, :N)
    @test keys(stateparametersrange(GenqoMultiplexedCascadedBellPairW)) ==
        (:ηᵇ, :ηᵈ, :ηᵗ, :N)
    @test GenqoMultiplexedCascadedBellPairW(1.0, 1.0, 1.0, 0.1) isa
        GenqoMultiplexedCascadedBellPairW
    @test_throws MethodError GenqoMultiplexedCascadedBellPairW(
        1.0,
        1.0,
        1.0,
        0.1,
        1e-8,
    )

    @test stateparameters(GenqoUnheraldedSPDCBellPairW) == (:ηᵈ, :ηᵗ, :N)
    @test keys(stateparametersrange(GenqoUnheraldedSPDCBellPairW)) == (:ηᵈ, :ηᵗ, :N)
    @test GenqoUnheraldedSPDCBellPairW(1.0, 1.0, 0.1) isa
        GenqoUnheraldedSPDCBellPairW
    @test_throws MethodError GenqoUnheraldedSPDCBellPairW(1.0, 1.0, 0.1, 1e-6)
end

@testset "StatesZoo ranges are exploration metadata" begin
    @test stateparametersrange(DepolarizedBellPair).p.max == 1
    @test DepolarizedBellPair(2.0) isa DepolarizedBellPair
end

end
