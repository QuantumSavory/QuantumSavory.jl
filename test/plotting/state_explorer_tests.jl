using Test
using QuantumSavory
using QuantumSavory.StatesZoo: BarrettKokBellPairW, stateexplorer
using CairoMakie

CairoMakie.activate!()

@testset "StatesZoo explorer uses family parameter metadata" begin
    figure = stateexplorer(BarrettKokBellPairW)

    @test figure isa Figure
end
