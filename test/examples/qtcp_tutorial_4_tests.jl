using Test

@testset "Examples - qtcp tutorial 4" begin
    include("../../examples/qtcp_tutorial/4_custom_endnode.jl")

    @test n_delivered_src == flow.npairs
    @test n_delivered_dst == flow.npairs
end
