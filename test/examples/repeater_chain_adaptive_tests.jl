using Test

@testset "Examples - repeater-chain-adaptive" begin
    include("../../examples/repeater-chain-adaptive/2_no_vis_cli.jl")
    @test length(fidelity_log) > 0
    @test maximum(fidelity_log) >= 0
end
