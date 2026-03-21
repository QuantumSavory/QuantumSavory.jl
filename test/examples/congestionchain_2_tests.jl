using Test

@testset "Examples - congestionchain 2" begin
    withenv("QS_CONGESTIONCHAIN_PORT" => "8892") do
        try
            include("../../examples/congestionchain/2_makie_interactive.jl")
        finally
            if isdefined(@__MODULE__, :server)
                close(server)
                wait(server)
            end
        end
    end
end
