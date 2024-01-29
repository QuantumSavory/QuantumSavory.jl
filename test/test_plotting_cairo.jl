using Test
using CairoMakie
CairoMakie.activate!()

@testset "register coordinates" begin
    include("test_plotting_1_regcoords.jl")
end
@testset "arguments and observables and tags" begin
    include("test_plotting_2_tags_observables.jl")
end
