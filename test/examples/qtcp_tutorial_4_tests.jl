using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs

@testset "Examples - qtcp tutorial 4" begin
    include("../../examples/qtcp_tutorial/4_custom_endnode.jl")

    graph = grid([5])
    regsize = 20
    sim, net = simulation_setup(graph, regsize; T2=100.0, EndNodeControllerType=CustomEndNodeController)

    put!(net[1], Flow(src=1, dst=5, npairs=15, uuid=1))
    run(sim, 500.0)

    mb1 = messagebuffer(net, 1)
    mb5 = messagebuffer(net, 5)

    @test count_tags(mb1, QTCPPairBegin) == 15
    @test count_tags(mb5, QTCPPairEnd) == 15
end
