using Test
using QuantumSavory

bell_contracts(refs) = (
    xx=observable(refs, QuantumSavory.X ⊗ QuantumSavory.X),
    zz=observable(refs, QuantumSavory.Z ⊗ QuantumSavory.Z),
    x1=observable(refs[1], QuantumSavory.X),
    z2=observable(refs[2], QuantumSavory.Z),
)

@testset "Representations dispatch" begin

@testset "raw backend states accept symbolic operators through default_repr" begin
    symbolic_state = copy(express(Z1, CliffordRepr()))
    explicit_state = copy(express(Z1, CliffordRepr()))

    apply!(symbolic_state, (1,), QuantumSavory.X)
    apply!(explicit_state, (1,), express(QuantumSavory.X, CliffordRepr(), UseAsOperation()))

    @test observable(symbolic_state, (1,), QuantumSavory.Z) ≈ -1
    @test observable(symbolic_state, (1,), QuantumSavory.Z) ≈
        observable(explicit_state, (1,), QuantumSavory.Z)
end

@testset "register collections match explicitly expressed operations" begin
    symbolic_regs = [Register(1, CliffordRepr()), Register(1, CliffordRepr())]
    explicit_regs = [Register(1, CliffordRepr()), Register(1, CliffordRepr())]

    for regs in (symbolic_regs, explicit_regs)
        initialize!(regs[1][1], X1)
        initialize!(regs[2][1], Z1)
    end

    apply!(symbolic_regs, (1, 1), CNOT)
    apply!(explicit_regs, (1, 1), express(CNOT, CliffordRepr(), UseAsOperation()))

    @test bell_contracts([symbolic_regs[1][1], symbolic_regs[2][1]]) ==
        bell_contracts([explicit_regs[1][1], explicit_regs[2][1]]) ==
        (xx=1, zz=1, x1=0, z2=0)
end

end
