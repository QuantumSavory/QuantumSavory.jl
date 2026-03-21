using Test

@testset "Examples - repeatergrid 2b" begin
    withenv("QS_SYNC_REPEATERGRID_PORT" => "8895") do
        try
            include("../../examples/repeatergrid/2b_sync_wglmakie_interactive.jl")
        finally
            if isdefined(@__MODULE__, :server)
                close(server)
                wait(server)
            end
        end
    end
end
