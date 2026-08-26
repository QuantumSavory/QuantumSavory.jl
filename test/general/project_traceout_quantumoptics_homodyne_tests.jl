using Test
using QuantumSavory

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
end
