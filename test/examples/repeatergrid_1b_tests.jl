using Test

@testset "Examples - repeatergrid 1b" begin
    try
        include("../../examples/repeatergrid/1b_async_wglmakie_interactive.jl")

        sim, _, obs, entlog, entlogaxis, histaxis, fid_axis, num_epr_axis, _, params = prepare_singlerun()
        running = Observable{Union{Bool, Nothing}}(true)
        continue_singlerun!(
            sim, obs, entlog, params, entlogaxis, histaxis, fid_axis, num_epr_axis, running;
            step_ts = range(0, 0.2, step=0.1),
        )

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
