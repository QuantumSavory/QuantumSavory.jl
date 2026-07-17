using Test
using Random
using Statistics: mean
using QuantumSavory
using QuantumOpticsBase: Ket, Operator

@testset "QuantumMCRepr structural dispatch" begin

@test :MCKet ∉ names(QuantumSavory)

@testset "MCKet lifecycle and manifold exits" begin
    reg = Register(
        [Qubit(), Qubit()],
        [QuantumMCRepr(), QuantumMCRepr()],
        [T2Dephasing(1.0), T2Dephasing(1.0)],
    )
    initialize!(reg[1], X1)
    @test reg.staterefs[1].state[] isa QuantumSavory.MCKet

    apply!(reg[1], Z)
    @test reg.staterefs[1].state[] isa QuantumSavory.MCKet

    initialize!(reg[2], Z1)
    subsystemcompose(reg[1], reg[2])
    @test reg.staterefs[1].state[] isa QuantumSavory.MCKet

    uptotime!(reg[1], 0.1)
    @test reg.staterefs[1].state[] isa QuantumSavory.MCKet

    project_traceout!(reg[1], σᶻ)
    @test reg.staterefs[2].state[] isa QuantumSavory.MCKet

    raw_reg = Register(1, QuantumMCRepr())
    initialize!(raw_reg[1], express(X1, QuantumOpticsRepr()))
    @test raw_reg.staterefs[1].state[] isa QuantumSavory.MCKet

    mixed_reg = Register(
        [Qubit(), Qubit()],
        [QuantumMCRepr(), QuantumOpticsRepr()],
    )
    initialize!(mixed_reg[1], X1)
    initialize!(mixed_reg[2], Z1)
    subsystemcompose(mixed_reg[1], mixed_reg[2])
    @test mixed_reg.staterefs[1].state[] isa Ket
    @test !(mixed_reg.staterefs[1].state[] isa QuantumSavory.MCKet)

    traced_reg = Register(2, QuantumMCRepr())
    initialize!(traced_reg[1:2], StabilizerState("XX ZZ"))
    traceout!(traced_reg[1])
    @test traced_reg.staterefs[2].state[] isa Operator

    evolved_reg = Register(1, QuantumMCRepr())
    initialize!(evolved_reg[1], X1)
    evolution = ConstantHamiltonianEvolution(IdentityOp(X1), 0.1)
    apply!(evolved_reg[1], evolution)
    @test evolved_reg.staterefs[1].state[] isa Operator

    damped_reg = Register(
        [Qumode()],
        [QuantumMCRepr()],
        [AmplitudeDamping(1.0)],
    )
    initialize!(damped_reg[1], F1)
    uptotime!(damped_reg[1], 0.1)
    @test damped_reg.staterefs[1].state[] isa Operator
end

@testset "T2 trajectory statistics" begin
    Random.seed!(0x490)
    Δt = 0.3
    samples = 2000
    values = map(1:samples) do _
        reg = Register(
            [Qubit()],
            [QuantumMCRepr()],
            [T2Dephasing(1.0)],
        )
        initialize!(reg[1], X1)
        uptotime!(reg[1], Δt)
        real(observable(reg[1], X))
    end
    trajectory_mean = mean(values)

    density_reg = Register(
        [Qubit()],
        [QuantumOpticsRepr()],
        [T2Dephasing(1.0)],
    )
    initialize!(density_reg[1], X1)
    uptotime!(density_reg[1], Δt)
    density_mean = real(observable(density_reg[1], X))

    @test trajectory_mean ≈ exp(-Δt) atol=0.05
    @test trajectory_mean ≈ density_mean atol=0.05
end

end
