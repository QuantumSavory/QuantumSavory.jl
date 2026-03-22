using Test

try
    include("../../examples/congestionchain/2_makie_interactive.jl")
finally
    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - congestionchain 2" begin
    @test true
end
