using Test

@testset "Examples - simpleswitch 2" begin
    withenv("QS_SIMPLESWITCH_PORT" => "8893") do
        try
            include("../../examples/simpleswitch/2_wglmakie_interactive.jl")
        finally
            if isdefined(@__MODULE__, :server)
                close(server)
                wait(server)
            end
        end
    end
end
