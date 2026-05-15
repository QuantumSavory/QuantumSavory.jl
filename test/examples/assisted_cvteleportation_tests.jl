using Test

@testset "Examples - assisted CV teleportation" begin
    include("../../examples/assisted_cvteleportation/setup.jl")

    result = run_assisted_teleportation(;
        input_state = CoherentState(0.25 + 0.15im),
        squeezes = fill(RESOURCE_SQUEEZE, 3),
    )

    @test result.fidelity > 0.99
    @test result.mean_error < 1e-2
    @test result.covariance_error < 1e-2
    @test result.initial_state ≈ result.teleported_state atol = 1e-2
end
