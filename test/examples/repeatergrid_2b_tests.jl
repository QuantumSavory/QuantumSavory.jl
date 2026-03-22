using Test

@testset "Examples - repeatergrid 2b" begin
    try
        include("../../examples/repeatergrid/2b_sync_wglmakie_interactive.jl")
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
