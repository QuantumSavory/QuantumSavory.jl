using Test

try
    include("../../examples/state_explorer/state_explorer.jl")
finally
    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - state explorer" begin
    @test true
end
