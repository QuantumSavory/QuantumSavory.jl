using Test
using Random
using Statistics: mean
using QuantumSavory
using QuantumOpticsBase: dm

struct ThrowingTraceoutState
    nsubsystems::Int
end

Base.copy(state::ThrowingTraceoutState) = state
QuantumSavory.nsubsystems(state::ThrowingTraceoutState) = state.nsubsystems
QuantumSavory.ispadded(::ThrowingTraceoutState) = false
QuantumSavory.traceout!(::ThrowingTraceoutState, ::Int) =
    error("state-level traceout was called")

function backreferences_are_consistent(stateref)
    length(stateref.registers) == length(stateref.registerindices) || return false
    all(enumerate(zip(stateref.registers, stateref.registerindices))) do (stateindex, item)
        reg, slot = item
        isnothing(reg) && return true
        reg.staterefs[slot] === stateref && reg.stateindices[slot] == stateindex
    end
end

@testset "traceout!" begin

@testset "QuantumMC stochastic partial trace" begin
    product_reg = Register(2, QuantumMCRepr())
    initialize!(product_reg[1:2], X1 ⊗ Z1)
    traceout!(product_reg[1])
    @test product_reg.staterefs[2].state[] isa QuantumSavory.MCKet
    @test observable(product_reg[2], Z) ≈ 1

    mode_qubit_reg = Register(
        [Qumode(), Qubit()],
        [QuantumMCRepr(), QuantumMCRepr()],
    )
    initialize!(mode_qubit_reg[1:2], (F0 ⊗ Z1 + F1 ⊗ Z2) / sqrt(2))
    traceout!(mode_qubit_reg[1])
    @test mode_qubit_reg.staterefs[2].state[] isa QuantumSavory.MCKet
    @test abs(real(observable(mode_qubit_reg[2], Z))) ≈ 1

    singleton_reg = Register(1, QuantumMCRepr())
    initialize!(singleton_reg[1], X1)
    singleton_state = singleton_reg.staterefs[1].state[]
    @test_throws ArgumentError traceout!(singleton_state, 1)
    traceout!(singleton_reg[1])
    @test !isassigned(singleton_reg, 1)

    bell = StabilizerState("XX ZZ")
    Random.seed!(0x4d43)
    trajectory_densities = map(1:2000) do _
        reg = Register(2, QuantumMCRepr())
        initialize!(reg[1:2], bell)
        traceout!(reg[1])
        dm(express(reg.staterefs[2].state[], QuantumOpticsRepr()))
    end
    trajectory_mean = mean(trajectory_densities)

    exact_reg = Register(2, QuantumOpticsRepr())
    initialize!(exact_reg[1:2], bell)
    traceout!(exact_reg[1])
    exact_density = exact_reg.staterefs[2].state[]

    @test trajectory_mean.data ≈ exact_density.data atol=0.05
end

@testset "complete StateRef groups skip backend reduction" begin
    regs = [Register(1) for _ in 1:4]
    first_state = initialize!(
        (regs[1][1], regs[2][1]),
        ThrowingTraceoutState(2),
    )
    second_state = initialize!(
        (regs[3][1], regs[4][1]),
        ThrowingTraceoutState(2),
    )

    result = traceout!(regs[4][1], regs[1][1], regs[3][1], regs[2][1])

    @test result isa Tuple
    @test all(result[i] === regs[j] for (i, j) in enumerate((4, 1, 3, 2)))
    @test all(reg -> !isassigned(reg, 1) && reg.stateindices[1] == 0, regs)
    @test isempty(first_state.registers)
    @test isempty(first_state.registerindices)
    @test isempty(second_state.registers)
    @test isempty(second_state.registerindices)

    duplicate_regs = [Register(1) for _ in 1:2]
    duplicate_state = initialize!(
        (duplicate_regs[1][1], duplicate_regs[2][1]),
        ThrowingTraceoutState(2),
    )
    @test_throws ErrorException traceout!(
        duplicate_regs[1][1],
        duplicate_regs[1][1],
    )
    @test backreferences_are_consistent(duplicate_state)

    incomplete_regs = [Register(1) for _ in 1:3]
    incomplete_state = initialize!(
        (incomplete_regs[1][1], incomplete_regs[2][1]),
        ThrowingTraceoutState(2),
    )
    initialize!(incomplete_regs[3][1], ThrowingTraceoutState(1))
    @test_throws ErrorException traceout!(
        incomplete_regs[3][1],
        incomplete_regs[2][1],
    )
    @test !isassigned(incomplete_regs[3], 1)
    @test backreferences_are_consistent(incomplete_state)
end

@testset "grouped deletion preserves RNG and return order" begin
    reg_a = Register(1, QuantumMCRepr())
    reg_b = Register(1, QuantumMCRepr())
    stateref = initialize!((reg_a[1], reg_b[1]), StabilizerState("XX ZZ"))

    Random.seed!(0x4d44)
    expected_next_sample = rand()
    Random.seed!(0x4d44)
    result = traceout!(reg_b[1], reg_a[1])
    observed_next_sample = rand()

    @test observed_next_sample == expected_next_sample
    @test result isa Tuple
    @test result[1] === reg_b
    @test result[2] === reg_a
    @test all(isnothing, reg_a.staterefs)
    @test all(isnothing, reg_b.staterefs)
    @test all(iszero, reg_a.stateindices)
    @test all(iszero, reg_b.stateindices)
    @test isempty(stateref.registers)
    @test isempty(stateref.registerindices)
end

end
