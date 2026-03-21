using Test

@testset "Examples - congestionchain" begin
    withenv("QS_CONGESTIONCHAIN_TEST" => "true") do
        include("../../examples/congestionchain/1_visualization.jl")
    end
end
