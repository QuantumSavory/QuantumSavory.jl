using Test

old_port = get(ENV, "QS_ASYNC_REPEATERGRID_PORT", nothing)
ENV["QS_ASYNC_REPEATERGRID_PORT"] = "8894"

try
    include("../../examples/repeatergrid/1b_async_wglmakie_interactive.jl")
finally
    if isnothing(old_port)
        delete!(ENV, "QS_ASYNC_REPEATERGRID_PORT")
    else
        ENV["QS_ASYNC_REPEATERGRID_PORT"] = old_port
    end

    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - repeatergrid 1b" begin
    @test true
end
