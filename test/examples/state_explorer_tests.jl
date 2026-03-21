using Test

@testset "Examples - state explorer" begin
    withenv("QS_SIMPLESWITCH_PORT" => "8896") do
        try
            include("../../examples/state_explorer/state_explorer.jl")
        finally
            if isdefined(@__MODULE__, :server)
                close(server)
                wait(server)
            end
        end
    end
end
