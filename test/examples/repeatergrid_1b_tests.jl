using Test

@testset "Examples - repeatergrid 1b" begin
    try
        include("../../examples/repeatergrid/1b_async_wglmakie_interactive.jl")
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
