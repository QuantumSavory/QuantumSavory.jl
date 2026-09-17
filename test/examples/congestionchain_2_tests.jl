using Test

@testset "Examples - congestionchain 2" begin
    try
        include("../../examples/congestionchain/2_makie_interactive.jl")

        sim, network, obs, ts, ax, ax_fidXX, ax_fidZZ = prepare_singlerun(Figure(); F = 1.0)
        running = Observable{Union{Bool, Nothing}}(true)
        continue_singlerun!(sim, network, (obs, ts), (ax, ax_fidXX, ax_fidZZ), running;
            step_ts = range(0, 0.2, step=0.1))
        @test now(sim) == 0.2
        @test isnothing(running[])
    finally
        if isdefined(@__MODULE__, :server)
            # The example may fail before the server is created.
            close(server)
            wait(server)
        end
    end
end
