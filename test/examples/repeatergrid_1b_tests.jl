using Test

@testset "Examples - repeatergrid 1b" begin
    withenv("QS_ASYNC_REPEATERGRID_PORT" => "8894") do
        try
            include("../../examples/repeatergrid/1b_async_wglmakie_interactive.jl")
        finally
            if isdefined(@__MODULE__, :server)
                close(server)
                wait(server)
            end
        end
    end
end
