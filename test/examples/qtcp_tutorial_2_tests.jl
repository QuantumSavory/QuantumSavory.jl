using Test

@testset "Examples - qtcp tutorial 2" begin
    tmpdir = mktempdir()
    output_path = joinpath(tmpdir, "qtcp_chain.mp4")
    ENV["QSAVORY_QTCP_TUTORIAL_2_OUTPUT"] = output_path
    try
        include("../../examples/qtcp_tutorial/2_chain_visualization.jl")

        @test n_delivered_src == flow.npairs
        @test n_delivered_dst == flow.npairs
        @test isfile(output_path)
    finally
        delete!(ENV, "QSAVORY_QTCP_TUTORIAL_2_OUTPUT")
    end
end
