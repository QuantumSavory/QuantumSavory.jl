using Test

old_port = get(ENV, "QS_CONGESTIONCHAIN_PORT", nothing)
ENV["QS_CONGESTIONCHAIN_PORT"] = "8892"

try
    include("../../examples/congestionchain/2_makie_interactive.jl")
finally
    if isnothing(old_port)
        delete!(ENV, "QS_CONGESTIONCHAIN_PORT")
    else
        ENV["QS_CONGESTIONCHAIN_PORT"] = old_port
    end

    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - congestionchain 2" begin
    @test true
end
