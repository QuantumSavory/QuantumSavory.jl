using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using CairoMakie
import InteractiveUtils, REPL
using QuantumSavory.QuantumOpticsBase: dm, Ket, Operator

@testset "show image/png" begin
    out = IOBuffer()

    reg_1q = Register(1)
    initialize!(reg_1q[1], X1)
    s_1q = QuantumSavory.stateof(reg_1q[1])
    # 1-qubit Ket
    show(out, MIME"image/png"(), reg_1q.staterefs[1])
    @test position(out) > 0

    reg_1q_mixed = Register(1)
    initialize!(reg_1q_mixed[1], dm(QuantumSavory.quantumstate(s_1q)))
    # 1-qubit Operator
    take!(out)
    show(out, MIME"image/png"(), reg_1q_mixed.staterefs[1])
    @test position(out) > 0

    reg_2q = Register(2)
    initialize!((reg_2q[1], reg_2q[2]), X1⊗Z1+Z1⊗X1)
    s_2q = QuantumSavory.stateof(reg_2q[1])
    # 2-qubit Ket
    take!(out)
    show(out, MIME"image/png"(), reg_2q.staterefs[1])
    @test position(out) > 0

    reg_2q_mixed = Register(2)
    initialize!((reg_2q_mixed[1], reg_2q_mixed[2]), dm(QuantumSavory.quantumstate(s_2q)))
    # 2-qubit Operator
    take!(out)
    show(out, MIME"image/png"(), reg_2q_mixed.staterefs[1])
    @test position(out) > 0

    reg_3q = Register(3)
    initialize!((reg_3q[1], reg_3q[2], reg_3q[3]), Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2)
    s_3q = QuantumSavory.stateof(reg_3q[1])
    # 3-qubit pure state
    take!(out)
    show(out, MIME"image/png"(), reg_3q.staterefs[1])
    @test position(out) > 0

    reg_3q_mixed = Register(3)
    initialize!((reg_3q_mixed[1], reg_3q_mixed[2], reg_3q_mixed[3]), dm(QuantumSavory.quantumstate(s_3q)))
    # 3-qubit Operator
    take!(out)
    show(out, MIME"image/png"(), reg_3q_mixed.staterefs[1])
    @test position(out) > 0

    reg_6q = Register(6)
    initialize!((reg_6q[1], reg_6q[2], reg_6q[3], reg_6q[4], reg_6q[5], reg_6q[6]), Z1⊗Z1⊗Z1⊗Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2⊗Z2⊗Z2⊗Z2)
    s_6q = QuantumSavory.stateof(reg_6q[1])
    # Large pure state
    take!(out)
    show(out, MIME"image/png"(), reg_6q.staterefs[1])
    @test position(out) > 0

    reg_6q_mixed = Register(6)
    initialize!((reg_6q_mixed[1], reg_6q_mixed[2], reg_6q_mixed[3], reg_6q_mixed[4], reg_6q_mixed[5], reg_6q_mixed[6]), dm(QuantumSavory.quantumstate(s_6q)))
    # Large mixed state
    take!(out)
    show(out, MIME"image/png"(), reg_6q_mixed.staterefs[1])
    @test position(out) > 0

    # Clifford
    reg_cliff = Register(1, CliffordRepr())
    initialize!(reg_cliff[1], X1)
    take!(out)
    show(out, MIME"image/png"(), reg_cliff.staterefs[1])
    @test position(out) > 0
end
