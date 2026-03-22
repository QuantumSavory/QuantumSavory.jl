using Test

old_port = get(ENV, "QS_SIMPLESWITCH_PORT", nothing)
ENV["QS_SIMPLESWITCH_PORT"] = "8896"

try
    include("../../examples/state_explorer/state_explorer.jl")
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

@testset "Examples - state explorer" begin
    @test true
end
