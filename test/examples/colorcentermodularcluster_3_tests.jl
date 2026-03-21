using Test

@testset "Examples - colorcentermodularcluster 3" begin
    withenv("QS_COLORCENTERMODCLUSTER_PORT" => "8891") do
        try
            include("../../examples/colorcentermodularcluster/3_makie_interactive.jl")
        finally
            if isdefined(@__MODULE__, :server)
                close(server)
                wait(server)
            end
        end
    end
end
