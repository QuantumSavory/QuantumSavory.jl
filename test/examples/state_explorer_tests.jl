using Test

@testset "Examples - state explorer" begin
    try
        include("../../examples/state_explorer/state_explorer.jl")
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
