using QuantumSavory
using Test
using CairoMakie
CairoMakie.activate!()

@testset "Plotting Cairo" begin
@testset "register coordinates" begin
    include("plotting_regcoords.jl")
end
@testset "arguments and observables and tags" begin
    include("plotting_tags_observables.jl")
end
@testset "background map" begin
    include("plotting_maps.jl")
end
end
