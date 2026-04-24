using Test

@testset "Examples - qtcp tutorial 3" begin
    include("../../examples/qtcp_tutorial/3_grid_multiflow.jl")

    @test flow1_src == flow1.npairs
    @test flow1_dst == flow1.npairs
    @test flow2_src == flow2.npairs
    @test flow2_dst == flow2.npairs
end
