using Test
using Random
using Statistics: mean, var
using QuantumSavory
using Gabs: QuadBlockBasis

function homodyne_samples(symbolic_state, representation, angle, shots)
    state = express(symbolic_state, representation)
    measurement = HomodyneMeasurement([angle]; squeeze = 1e-12)

    map(1:shots) do _
        register = Register([Qumode()], [representation])
        initialize!(register[1], state)
        result = project_traceout!(register[1], measurement)

        # Gabs uses ħ=2 phase-space coordinates. Normalize its measured
        # quadrature to match the QuantumOptics convention [x,p]=i.
        result isa Real ? result :
            (cos(angle) * result[1] + sin(angle) * result[2]) / sqrt(2)
    end
end

@testset "QuantumOptics homodyne measurement" begin
    register = Register([Qubit(), Qumode()])
    initialize!(register[1:2], Z1 ⊗ F0)

    interaction = σ₋ ⊗ Create + σ₊ ⊗ Destroy
    apply!(register[1:2], exp(-im * (π / 4) * interaction))

    x = project_traceout!(register[2], HomodyneMeasurement([0.0]))
    if !isapprox(x, 0; atol = 1e-12)
        apply!(register[1], exp(im * atan(sqrt(2) * x) * X))
    end

    @test x isa Real
    expected_outcomes = (-sqrt(3 / 2), 0, sqrt(3 / 2))
    @test any(isapprox(x, value; atol = 1e-12) for value in expected_outcomes)
    @test !isassigned(register, 2)
    @test real(observable(register[1], SProjector(Z1))) ≈ 1 atol = 1e-7

    density_register = Register([Qumode()])
    initialize!(density_register[1], SProjector(F0))
    rotated_x = project_traceout!(density_register[1], HomodyneMeasurement([π / 3]))
    @test any(isapprox(rotated_x, value; atol = 1e-12) for value in expected_outcomes)
    @test !isassigned(density_register, 1)

    invalid_angles = Register([Qumode()])
    initialize!(invalid_angles[1], F0)
    @test_throws ArgumentError project_traceout!(
        invalid_angles[1], HomodyneMeasurement([0.0, π / 2])
    )
    @test isassigned(invalid_angles, 1)

    qubit = Register(1)
    initialize!(qubit[1], Z1)
    @test_throws ArgumentError project_traceout!(qubit[1], HomodyneMeasurement([0.0]))
    @test isassigned(qubit, 1)

    @testset "Means and variances agree with Gabs" begin
        shots = 2_000
        # This is more than four standard errors for the moment differences below.
        statistical_tolerance = 0.10
        quantumoptics_repr = QuantumOpticsRepr(cutoff = 6)
        gabs_repr = GabsRepr(QuadBlockBasis)
        cases = (
            ("vacuum x", F0, 0.0),
            ("vacuum p", F0, pi / 2),
            ("coherent x", CoherentState(0.3 + 0.2im), 0.0),
            ("coherent p", CoherentState(0.3 + 0.2im), pi / 2),
        )

        rng = Random.default_rng()
        saved_rng = copy(rng)
        try
            Random.seed!(rng, 0x5158)
            for (name, state, angle) in cases
                @testset "$name" begin
                    quantumoptics = homodyne_samples(
                        state, quantumoptics_repr, angle, shots
                    )
                    gabs = homodyne_samples(state, gabs_repr, angle, shots)

                    @test mean(quantumoptics) ≈ mean(gabs) atol = statistical_tolerance
                    @test var(quantumoptics) ≈ var(gabs) atol = statistical_tolerance
                end
            end
        finally
            copy!(rng, saved_rng)
        end
    end
end
