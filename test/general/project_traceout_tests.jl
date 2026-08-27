using Test
using QuantumSavory

const bell = StabilizerState("XX ZZ")
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

@testset "Project Traceout" begin

@testset "Explicit basis outcomes" begin
    register = Register(2)
    initialize!(register[1:2], Z1 ⊗ Z2)

    @test project_traceout!(register[1], (Z1, Z2)) == 1
    @test !isassigned(register, 1)
    @test isassigned(register, 2)

    @test project_traceout!(register[2], (Z1, Z2), ("up", 2//3)) == 2//3
    @test !isassigned(register, 2)

    outcome, remaining = project_traceout!(
        express(Z2), 1, (Z1, Z2), (:same, :same)
    )
    @test outcome === :same
    @test remaining === nothing

    callback_outcome = Ref{Any}()
    callback_register = Register(1)
    initialize!(callback_register[1], Z1)
    result = project_traceout!(callback_register[1], (Z1, Z2)) do value
        callback_outcome[] = value
        :callback_complete
    end
    @test result === :callback_complete
    @test callback_outcome[] == 1

    initialize!(callback_register[1], Y2)
    result = project_traceout!(callback_register[1], Y) do value
        callback_outcome[] = value
        :operator_callback_complete
    end
    @test result === :operator_callback_complete
    @test callback_outcome[] == -1
end

@testset "Labeled basis validation precedes mutation" begin
    register = Register(2)
    initialize!(register[1:2], bell)
    stateref = QuantumSavory.stateof(register[1])
    stored_state = stateref.state[]
    staterefs = copy(register.staterefs)
    stateindices = copy(register.stateindices)
    accesstimes = copy(register.accesstimes)
    backref_registers = copy(stateref.registers)
    backref_indices = copy(stateref.registerindices)

    @test_throws DimensionMismatch project_traceout!(
        register[1], (Z1, Z2), (:only,); time=1.0
    )
    @test stateref.state[] === stored_state
    @test all(current === saved for (current, saved) in zip(register.staterefs, staterefs))
    @test register.stateindices == stateindices
    @test register.accesstimes == accesstimes
    @test all(current === saved for (current, saved) in zip(stateref.registers, backref_registers))
    @test stateref.registerindices == backref_indices
    @test isassigned(register, 1)
    @test isassigned(register, 2)

    @test_throws DimensionMismatch project_traceout!(
        stored_state, 1, (Z1, Z2), (:only,)
    )

    empty = Register(1)
    initial_time = empty.accesstimes[1]
    @test_throws DimensionMismatch project_traceout!(
        empty[1], (Z1, Z2), (:only,); time=1.0
    )
    @test empty.accesstimes[1] == initial_time
    @test !isassigned(empty, 1)
end

for rep in [QuantumOpticsRepr(), QuantumMCRepr(), CliffordRepr()]
    for (operator, eigenstates) in ((X, (X1, X2)), (Y, (Y1, Y2)), (Z, (Z1, Z2)))
        for (eigenstate, eigenvalue) in zip(eigenstates, (1, -1))
            eigenstate_register = Register(1, rep)
            initialize!(eigenstate_register[1], eigenstate)
            @test project_traceout!(eigenstate_register[1], operator) == eigenvalue
            @test !isassigned(eigenstate_register, 1)
        end
    end

    a = Register(2,rep)
    initialize!(a[1:2], bell)
    m1 = project_traceout!(a[1], Y)
    @test m1 isa Int
    @test m1 in (-1, 1)
    @test !isassigned(a, 1)
    @test isassigned(a, 2)
    m2 = project_traceout!(a[2], Y)
    @test m2 isa Int
    @test m2 in (-1, 1)
    @test m1 * m2 == -1
    @test !isassigned(a, 2)

    a = Register(4,rep)
    @test_throws "Attempting to initialize a set of registers with a state that does not have the correct number of subsystems." initialize!(a[1:2], bell⊗bell)
    initialize!(a[1:4], bell⊗bell)
    m1 = project_traceout!(a[1], Y)
    m2 = project_traceout!(a[2], Y)
    m3 = project_traceout!(a[3], Y)
    m4 = project_traceout!(a[4], Y)
    @test m1 * m2 == -1
    @test m3 * m4 == -1

    a = Register(2,rep)
    initialize!(a[1], X1)
    @test project_traceout!(a[1], σˣ) == 1
end

mc_register = Register(2, QuantumMCRepr())
initialize!(mc_register[1:2], Z1 ⊗ Z2)
@test project_traceout!(mc_register[1], Z) == 1
@test mc_register.staterefs[2].state[] isa QuantumSavory.MCKet

empty = Register(1)
initial_time = empty.accesstimes[1]
error = try
    project_traceout!(empty[1], Z; time=1)
catch error
    error
end
@test error == ArgumentError("Cannot project and trace out an unassigned register slot.")
@test empty.accesstimes[1] == initial_time
@test !isassigned(empty, 1)

r = Register(1)
initialize!(r[1], Z)
@test_throws "State not normalized. Could be due to passing wrong state to `initialize!`" project_traceout!(r[1], (L0, L1))
end
