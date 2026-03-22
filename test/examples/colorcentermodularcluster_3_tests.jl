using Test

try
    include("../../examples/colorcentermodularcluster/3_makie_interactive.jl")
finally
    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - colorcentermodularcluster 3" begin
    @test true
end
