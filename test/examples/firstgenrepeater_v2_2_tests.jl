using Test

try
    include("../../examples/firstgenrepeater_v2/2_swapper_example.jl")
finally
    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - firstgenrepeater_v2 2" begin
    @test true
end
