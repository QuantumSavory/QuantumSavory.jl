using Test
using QuantumSavory

const bell = StabilizerState("XX ZZ")
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

@testset "Project Traceout" begin

for rep in [QuantumOpticsRepr(), QuantumMCRepr(), CliffordRepr()]
    a = Register(2,rep)
    initialize!(a[1:2], bell)
    m1 = project_traceout!(a[1], Y)
    @test m1 isa Int
    @test m1 in 1:2
    @test !isassigned(a, 1)
    @test isassigned(a, 2)
    m2 = project_traceout!(a[2], Y)
    @test m2 isa Int
    @test m2 in 1:2
    @test m1 != m2
    @test !isassigned(a, 2)

    a = Register(4,rep)
    @test_throws "Attempting to initialize a set of registers with a state that does not have the correct number of subsystems." initialize!(a[1:2], bell⊗bell)
    initialize!(a[1:4], bell⊗bell)
    m1 = project_traceout!(a[1], Y)
    m2 = project_traceout!(a[2], Y)
    m3 = project_traceout!(a[3], Y)
    m4 = project_traceout!(a[4], Y)
    @test m1!=m2
    @test m3!=m4

    a = Register(2,rep)
    initialize!(a[1], X1)
    @test project_traceout!(a[1], σˣ) == 1
end

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
