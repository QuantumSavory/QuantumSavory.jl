using Test

try
    include("../../examples/simpleswitch/2_wglmakie_interactive.jl")
finally
    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - simpleswitch 2" begin
    @test true
end
