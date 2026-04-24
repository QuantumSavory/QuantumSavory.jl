using Test

@testset "Examples - qtcp tutorial 1" begin
    include("../../examples/qtcp_tutorial/1_chain_basic.jl")

    @test n_delivered_src == flow.npairs
    @test n_delivered_dst == flow.npairs
end
