using Test

@testset "Examples - qtcp tutorial 5" begin
    include("../../examples/qtcp_tutorial/5_external_entanglement_inventory.jl")

    @test flow1_src == 5
    @test flow1_dst == 5
    @test flow2_src == 5
    @test flow2_dst == 5
end
