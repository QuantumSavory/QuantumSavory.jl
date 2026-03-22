using Test

old_port = get(ENV, "QS_SYNC_REPEATERGRID_PORT", nothing)
ENV["QS_SYNC_REPEATERGRID_PORT"] = "8895"

try
    include("../../examples/repeatergrid/2b_sync_wglmakie_interactive.jl")
finally
    if isnothing(old_port)
        delete!(ENV, "QS_SYNC_REPEATERGRID_PORT")
    else
        ENV["QS_SYNC_REPEATERGRID_PORT"] = old_port
    end

    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - repeatergrid 2b" begin
    @test true
end
