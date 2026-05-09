using Test

@testset "Examples - firstgenrepeater_v2 2" begin
    try
        include("../../examples/firstgenrepeater_v2/2_swapper_example.jl")
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
