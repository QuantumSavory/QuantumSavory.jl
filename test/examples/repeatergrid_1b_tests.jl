using Test

try
    include("../../examples/repeatergrid/1b_async_wglmakie_interactive.jl")
finally
    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - repeatergrid 1b" begin
    @test true
end
