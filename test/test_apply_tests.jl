@testset "Apply" begin
using Test
using QuantumSavory

gate = tensor(X, Z)
express(gate, CliffordRepr(), UseAsOperation())

reg = Register([Qubit(), Qubit()], [CliffordRepr(), CliffordRepr()])
initialize!(reg[1], Z1)
initialize!(reg[2], X1)
apply!(reg[1:2], gate)

@test observable(reg[1], Z) ≈ -1
@test observable(reg[2], X) ≈ -1

end
