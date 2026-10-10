using Test

@testset "Examples - bb84qkd 3" begin
    # Keep this wrapper deterministic even when it is included directly rather
    # than through test/runtests.jl, which also enables QS_TESTRUN globally.
    withenv("QS_TESTRUN" => "true") do
        include("../../examples/bb84qkd/3_makie_interactive.jl")
    end

    @test stats.sifted > 0
    @test now(sim) == 100.0
    @test length(qber_points[]) == stats.sifted
    @test length(key_points[]) == stats.sifted
    @test last(key_points[])[2] == stats.sifted

    # Exercise the same observable callbacks used by the UI controls.
    s_p.value[] = 0.75
    s_t.value[] = 0.5
    @test intercept_prob[] == 0.75
    @test period[] == 0.5
    previous_rounds = stats.rounds
    run(sim, 120.0)
    refresh_bb84_plots!()
    @test stats.rounds > previous_rounds
    @test length(qber_points[]) == length(key_points[]) == stats.sifted
end
