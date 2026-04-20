using Test

@testset "Examples - colorcentermodularcluster 3" begin
    try
        include("../../examples/colorcentermodularcluster/3_makie_interactive.jl")
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
