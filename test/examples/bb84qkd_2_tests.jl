using Test

@testset "Examples - bb84qkd 2" begin
    include("../../examples/bb84qkd/2_sweep_viz.jl")

    @test length(mean_qbers) == length(intercept_probs)
    @test mean_qbers[1] == 0.0
    @test abs(mean_qbers[end] - 0.25) < 0.06
end
