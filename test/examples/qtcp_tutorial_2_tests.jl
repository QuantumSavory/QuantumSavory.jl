using Test

@testset "Plotting - qtcp tutorial 2" begin
    include("../../examples/qtcp_tutorial/2_chain_visualization.jl")

    @test n_delivered_src == flow.npairs
    @test n_delivered_dst == flow.npairs
    @test isfile(output_path)
end
