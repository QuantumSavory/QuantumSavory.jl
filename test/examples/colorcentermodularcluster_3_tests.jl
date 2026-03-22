using Test

old_port = get(ENV, "QS_COLORCENTERMODCLUSTER_PORT", nothing)
ENV["QS_COLORCENTERMODCLUSTER_PORT"] = "8891"

try
    include("../../examples/colorcentermodularcluster/3_makie_interactive.jl")
finally
    if isnothing(old_port)
        delete!(ENV, "QS_COLORCENTERMODCLUSTER_PORT")
    else
        ENV["QS_COLORCENTERMODCLUSTER_PORT"] = old_port
    end

    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - colorcentermodularcluster 3" begin
    @test true
end
