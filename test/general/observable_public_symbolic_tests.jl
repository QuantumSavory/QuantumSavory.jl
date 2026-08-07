using Test
using QuantumSavory

@testset "seven-qubit symbolic Clifford observable" begin
    steane_zero = StabilizerState(
        "ZIZIZIZ XIXIXIX IZZIIZZ IXXIIXX IIIZZZZ IIIXXXX ZZZZZZZ"
    )
    register = Register(7, CliffordRepr())
    initialize!(register[1:7], steane_zero)

    generator = Z ⊗ I ⊗ Z ⊗ I ⊗ Z ⊗ I ⊗ Z
    @test observable(register[1:7], generator) ≈ 1
end
