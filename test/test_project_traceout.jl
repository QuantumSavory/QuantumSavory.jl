using Test
using QuantumSavory

const bell = StabilizerState("XX ZZ")
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

for rep in [QuantumOpticsRepr(), CliffordRepr()]
    a = Register(2,rep)
    initialize!(a[1:2], bell)
    m1 = project_traceout!(a[1], σʸ)
    m2 = project_traceout!(a[2], σʸ)
    @test m1!=m2

    a = Register(4,rep)
    @test_throws "Attempting to initialize a set of registers with a state that does not have the correct number of subsystems." initialize!(a[1:2], bell⊗bell)
    initialize!(a[1:4], bell⊗bell)
    m1 = project_traceout!(a[1], σʸ)
    m2 = project_traceout!(a[2], σʸ)
    m3 = project_traceout!(a[3], σʸ)
    m4 = project_traceout!(a[4], σʸ)
    @test m1!=m2
    @test m3!=m4

    a = Register(2,rep)
    initialize!(a[1], X1)
    @test project_traceout!(a[1], σˣ) == 1
end
