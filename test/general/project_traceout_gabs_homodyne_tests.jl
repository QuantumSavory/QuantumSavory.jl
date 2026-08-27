using Test
using Random
using QuantumSavory
using Gabs

backend_state(r::RegRef) = QuantumSavory.stateof(r).state[]

function direct_homodyne_traceout(
    symbolic_state,
    representation,
    measured_mode::Int,
    measurement::HomodyneMeasurement,
    seed::Integer;
    operations = (),
)
    state = express(symbolic_state, representation)
    for (indices, op) in operations
        apply!(state, indices, express(op, representation))
    end
    Random.seed!(seed)
    coordinates, collapsed = Gabs.homodyne(
        state,
        [measured_mode],
        measurement.angles;
        squeeze = measurement.squeeze,
    )
    return coordinates, Gabs.ptrace(collapsed, measured_mode)
end

@testset "Project Traceout Gabs Homodyne" begin
for (basis_type, basis_name) in (
    (QuadPairBasis, "QuadPairBasis"),
    (QuadBlockBasis, "QuadBlockBasis"),
)
    @testset "$basis_name coordinates" begin
        representation = GabsRepr(basis_type)

        @testset "Product coherent state leaves the other mode untouched" begin
            α = 0.35 + 0.15im
            β = -0.7 + 0.25im
            symbolic_state = CoherentState(α) ⊗ CoherentState(β)
            expected_state = express(CoherentState(β), representation)
            measurement = HomodyneMeasurement([0.0]; squeeze = 1e-12)
            seed = 11
            expected_coordinates, _ = direct_homodyne_traceout(
                symbolic_state, representation, 1, measurement, seed
            )

            reg = Register(fill(Qumode(), 2), fill(representation, 2))
            initialize!(reg[1:2], symbolic_state)

            Random.seed!(seed)
            result = project_traceout!(reg[1], measurement)
            actual_state = backend_state(reg[2])

            @test result isa Complex
            @test result ≈ complex(expected_coordinates[1], expected_coordinates[2]) atol = 1e-12
            @test reg.staterefs[1] === nothing
            @test Gabs.nmodes(actual_state.basis) == 1
            @test isapprox(actual_state, expected_state; atol = 1e-12)
        end

        @testset "Balanced beamsplitter case matches direct Gaussian reference" begin
            α = 0.4 - 0.2im
            symbolic_state = CoherentState(α) ⊗ CoherentState(α)
            measurement = HomodyneMeasurement([0.0]; squeeze = 1e-12)
            seed = 23

            expected_coordinates, expected_state = direct_homodyne_traceout(
                symbolic_state,
                representation,
                2,
                measurement,
                seed;
                operations = (([1, 2], BeamSplitterOp(1 / 2)),),
            )

            reg = Register(fill(Qumode(), 2), fill(representation, 2))
            initialize!(reg[1:2], symbolic_state)
            apply!(reg[1:2], BeamSplitterOp(1 / 2))

            Random.seed!(seed)
            result = project_traceout!(reg[2], measurement)
            actual_state = backend_state(reg[1])

            @test result ≈ complex(expected_coordinates[1], expected_coordinates[2]) atol = 1e-12
            @test reg.staterefs[2] === nothing
            @test isapprox(actual_state, expected_state; atol = 1e-12)
        end

        @testset "Two-mode squeezing x-homodyne agrees with direct Gabs reference" begin
            symbolic_state = TwoSqueezedState(0.45)
            measurement = HomodyneMeasurement([0.0]; squeeze = 1e-12)
            seed = 31

            expected_coordinates, expected_state = direct_homodyne_traceout(
                symbolic_state, representation, 1, measurement, seed
            )

            reg = Register(fill(Qumode(), 2), fill(representation, 2))
            initialize!(reg[1:2], symbolic_state)

            Random.seed!(seed)
            result = project_traceout!(reg[1], measurement)
            actual_state = backend_state(reg[2])

            @test result ≈ complex(expected_coordinates[1], expected_coordinates[2]) atol = 1e-12
            @test isapprox(actual_state, expected_state; atol = 1e-12)
        end

        @testset "Two-mode squeezing p-homodyne stays indexed correctly" begin
            symbolic_state = TwoSqueezedState(0.45)
            measurement = HomodyneMeasurement([pi / 2]; squeeze = 1e-12)
            seed = 47

            expected_coordinates, expected_state = direct_homodyne_traceout(
                symbolic_state, representation, 2, measurement, seed
            )

            reg = Register(fill(Qumode(), 2), fill(representation, 2))
            initialize!(reg[1:2], symbolic_state)

            Random.seed!(seed)
            result = project_traceout!(reg[2], measurement)
            actual_state = backend_state(reg[1])

            @test result ≈ complex(expected_coordinates[1], expected_coordinates[2]) atol = 1e-12
            @test isapprox(actual_state, expected_state; atol = 1e-12)
        end

        @testset "Validation precedes sampling and traceout" begin
            reg = Register(fill(Qumode(), 2), fill(representation, 2))
            initialize!(reg[1:2], TwoSqueezedState(0.45))
            stored_state = QuantumSavory.stateof(reg[1]).state[]

            @test_throws ArgumentError project_traceout!(
                reg[1], HomodyneMeasurement([0.0, pi / 2])
            )
            @test QuantumSavory.stateof(reg[1]).state[] === stored_state
            @test isassigned(reg, 1) && isassigned(reg, 2)

            @test_throws BoundsError project_traceout!(
                stored_state, 3, HomodyneMeasurement([0.0])
            )
            @test QuantumSavory.stateof(reg[1]).state[] === stored_state
            @test isassigned(reg, 1) && isassigned(reg, 2)
        end
    end
end
end
