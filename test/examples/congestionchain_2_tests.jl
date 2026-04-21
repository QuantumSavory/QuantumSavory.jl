using Test

@testset "Examples - congestionchain 2" begin
    try
        include("../../examples/congestionchain/2_makie_interactive.jl")
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
