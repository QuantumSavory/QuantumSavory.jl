@testitem "Plotting Cairo" tags=[:plotting_cairo] begin
    include("setup_plotting.jl")
    using CairoMakie
    CairoMakie.activate!()

    @testset "register coordinates" begin
        include("test_plotting_1_regcoords.jl")
    end
    @testset "arguments and observables and tags" begin
        include("test_plotting_2_tags_observables.jl")
    end
end
