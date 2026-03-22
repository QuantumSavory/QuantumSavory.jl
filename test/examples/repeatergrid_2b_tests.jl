using Test

try
    include("../../examples/repeatergrid/2b_sync_wglmakie_interactive.jl")
finally
    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - repeatergrid 2b" begin
    @test true
end
