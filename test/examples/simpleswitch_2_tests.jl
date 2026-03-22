using Test

old_port = get(ENV, "QS_SIMPLESWITCH_PORT", nothing)
ENV["QS_SIMPLESWITCH_PORT"] = "8893"

try
    include("../../examples/simpleswitch/2_wglmakie_interactive.jl")
finally
    if isnothing(old_port)
        delete!(ENV, "QS_SIMPLESWITCH_PORT")
    else
        ENV["QS_SIMPLESWITCH_PORT"] = old_port
    end

    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - simpleswitch 2" begin
    @test true
end
