using Test
using Random
using QuantumSavory
using Gabs

const GABS_QBLOCK_REPR = GabsRepr(QuadBlockBasis)

backend_state(r::RegRef) = QuantumSavory.stateof(r).state[]

function direct_homodyne_traceout(
    symbolic_state,
    measured_mode::Int,
    measurement::HomodyneMeasurement,
    seed::Integer;
    operations = (),
)
    state = express(symbolic_state, GABS_QBLOCK_REPR)
    for (indices, op) in operations
        apply!(state, indices, express(op, GABS_QBLOCK_REPR))
    end
    Random.seed!(seed)
    result, collapsed = Gabs.homodyne(
        state,
        [measured_mode],
        measurement.angles;
        squeeze = measurement.squeeze,
    )
    return result, Gabs.ptrace(collapsed, measured_mode)
end

@testset "Project Traceout Gabs Homodyne" begin
    @testset "Product coherent state leaves the other mode untouched" begin
        α = 0.35 + 0.15im
        β = -0.7 + 0.25im
        symbolic_state = CoherentState(α) ⊗ CoherentState(β)
        expected_state = express(CoherentState(β), GABS_QBLOCK_REPR)
        measurement = HomodyneMeasurement([0.0]; squeeze = 1e-12)

        reg = Register(fill(Qumode(), 2), fill(GABS_QBLOCK_REPR, 2))
        initialize!(reg[1:2], symbolic_state)

        Random.seed!(11)
        result = project_traceout!(reg[1], measurement)
        actual_state = backend_state(reg[2])

        @test length(result) == 2
        @test reg.staterefs[1] === nothing
        @test Gabs.nmodes(actual_state.basis) == 1
        @test isapprox(actual_state, expected_state; atol = 1e-12)
    end

    @testset "Balanced beamsplitter case matches direct Gaussian reference" begin
        α = 0.4 - 0.2im
        symbolic_state = CoherentState(α) ⊗ CoherentState(α)
        measurement = HomodyneMeasurement([0.0]; squeeze = 1e-12)
        seed = 23

        _, expected_state = direct_homodyne_traceout(
            symbolic_state,
            2,
            measurement,
            seed;
            operations = (([1, 2], BeamSplitterOp(1 / 2)),),
        )

        reg = Register(fill(Qumode(), 2), fill(GABS_QBLOCK_REPR, 2))
        initialize!(reg[1:2], symbolic_state)
        apply!(reg[1:2], BeamSplitterOp(1 / 2))

        Random.seed!(seed)
        project_traceout!(reg[2], measurement)
        actual_state = backend_state(reg[1])

        @test reg.staterefs[2] === nothing
        @test isapprox(actual_state, expected_state; atol = 1e-12)
    end

    @testset "Two-mode squeezing x-homodyne agrees with direct Gabs reference" begin
        symbolic_state = TwoSqueezedState(0.45)
        measurement = HomodyneMeasurement([0.0]; squeeze = 1e-12)
        seed = 31

        expected_result, expected_state = direct_homodyne_traceout(
            symbolic_state,
            1,
            measurement,
            seed,
        )

        reg = Register(fill(Qumode(), 2), fill(GABS_QBLOCK_REPR, 2))
        initialize!(reg[1:2], symbolic_state)

        Random.seed!(seed)
        result = project_traceout!(reg[1], measurement)
        actual_state = backend_state(reg[2])

        @test isapprox(result, expected_result; atol = 1e-12)
        @test isapprox(actual_state, expected_state; atol = 1e-12)
    end

    @testset "Two-mode squeezing p-homodyne on the second mode stays indexed correctly" begin
        symbolic_state = TwoSqueezedState(0.45)
        measurement = HomodyneMeasurement([pi / 2]; squeeze = 1e-12)
        seed = 47

        expected_result, expected_state = direct_homodyne_traceout(
            symbolic_state,
            2,
            measurement,
            seed,
        )

        reg = Register(fill(Qumode(), 2), fill(GABS_QBLOCK_REPR, 2))
        initialize!(reg[1:2], symbolic_state)

        Random.seed!(seed)
        result = project_traceout!(reg[2], measurement)
        actual_state = backend_state(reg[1])

        @test isapprox(result, expected_result; atol = 1e-12)
        @test isapprox(actual_state, expected_state; atol = 1e-12)
    end
end
