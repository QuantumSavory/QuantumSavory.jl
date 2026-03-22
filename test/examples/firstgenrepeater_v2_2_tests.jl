using Test

old_port = get(ENV, "QS_FIRSTGENREPEATER_V2_PORT", nothing)
ENV["QS_FIRSTGENREPEATER_V2_PORT"] = "8890"

try
    include("../../examples/firstgenrepeater_v2/2_swapper_example.jl")
finally
    if isnothing(old_port)
        delete!(ENV, "QS_FIRSTGENREPEATER_V2_PORT")
    else
        ENV["QS_FIRSTGENREPEATER_V2_PORT"] = old_port
    end

    if isdefined(@__MODULE__, :server)
        close(server)
        wait(server)
    end
end

@testset "Examples - firstgenrepeater_v2 2" begin
    @test true
end
