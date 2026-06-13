using Test
using QuantumSavory
using QuantumSavory.QuantumOpticsBase: dm, Ket, Operator

struct UnknownState end

@testset "StateRef text/plain display" begin
    out = IOBuffer()

    reg_1q = Register(1)
    initialize!(reg_1q[1], X1)
    s_1q = QuantumSavory.stateof(reg_1q[1])
    # 1-qubit pure
    show(out, MIME"text/plain"(), s_1q)
    txt = String(take!(out))
    @test occursin("Single-qubit state", txt)

    reg_1q_mixed = Register(1)
    initialize!(reg_1q_mixed[1], dm(QuantumSavory.quantumstate(s_1q)))
    s_1q_mixed = QuantumSavory.stateof(reg_1q_mixed[1])
    # 1-qubit mixed
    show(out, MIME"text/plain"(), s_1q_mixed)
    txt = String(take!(out))
    @test occursin("Single-qubit state", txt)
    @test occursin("Density matrix", txt)

    reg_2q = Register(2)
    initialize!((reg_2q[1], reg_2q[2]), X1⊗Z1+Z1⊗X1)
    s_2q = QuantumSavory.stateof(reg_2q[1])
    # 2-qubit pure
    show(out, MIME"text/plain"(), s_2q)
    txt = String(take!(out))
    @test occursin("Two-qubit state", txt)

    reg_2q_mixed = Register(2)
    initialize!((reg_2q_mixed[1], reg_2q_mixed[2]), dm(QuantumSavory.quantumstate(s_2q)))
    s_2q_mixed = QuantumSavory.stateof(reg_2q_mixed[1])
    # 2-qubit mixed
    show(out, MIME"text/plain"(), s_2q_mixed)
    txt = String(take!(out))
    @test occursin("Two-qubit state", txt)

    reg_3q = Register(3)
    initialize!((reg_3q[1], reg_3q[2], reg_3q[3]), Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2)
    s_3q = QuantumSavory.stateof(reg_3q[1])
    # 3-qubit pure
    show(out, MIME"text/plain"(), s_3q)
    txt = String(take!(out))
    @test occursin("3-qubit pure state", txt)

    reg_3q_mixed = Register(3)
    initialize!((reg_3q_mixed[1], reg_3q_mixed[2], reg_3q_mixed[3]), dm(QuantumSavory.quantumstate(s_3q)))
    s_3q_mixed = QuantumSavory.stateof(reg_3q_mixed[1])
    # 3-qubit mixed
    show(out, MIME"text/plain"(), s_3q_mixed)
    txt = String(take!(out))
    @test occursin("3-qubit mixed state", txt)

    reg_6q = Register(6)
    initialize!((reg_6q[1], reg_6q[2], reg_6q[3], reg_6q[4], reg_6q[5], reg_6q[6]), Z1⊗Z1⊗Z1⊗Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2⊗Z2⊗Z2⊗Z2)
    s_6q = QuantumSavory.stateof(reg_6q[1])
    # Large pure
    show(out, MIME"text/plain"(), s_6q)
    txt = String(take!(out))
    @test occursin("6-qubit state", txt)

    reg_6q_mixed = Register(6)
    initialize!((reg_6q_mixed[1], reg_6q_mixed[2], reg_6q_mixed[3], reg_6q_mixed[4], reg_6q_mixed[5], reg_6q_mixed[6]), dm(QuantumSavory.quantumstate(s_6q)))
    s_6q_mixed = QuantumSavory.stateof(reg_6q_mixed[1])
    # Large mixed
    show(out, MIME"text/plain"(), s_6q_mixed)
    txt = String(take!(out))
    @test occursin("6-qubit state", txt)
    @test occursin("Top-8 probabilities", txt)

    # Generic
    QuantumSavory.stateshow(out, MIME"text/plain"(), UnknownState(), nothing)
    txt = String(take!(out))
    @test occursin("State of type", txt)

    # Clifford
    reg = Register(1, CliffordRepr())
    initialize!(reg[1], X1)
    show(out, MIME"text/plain"(), QuantumSavory.stateof(reg[1]))
    txt = String(take!(out))
    @test occursin("Stabilizer state", txt)
end

@testset "StateRef text/html display" begin
    out = IOBuffer()

    reg_1q = Register(1)
    initialize!(reg_1q[1], X1)
    s_1q = QuantumSavory.stateof(reg_1q[1])
    show(out, MIME"text/html"(), s_1q)
    html = String(take!(out))
    @test occursin("Single-qubit state", html)

    reg_1q_mixed = Register(1)
    initialize!(reg_1q_mixed[1], dm(QuantumSavory.quantumstate(s_1q)))
    s_1q_mixed = QuantumSavory.stateof(reg_1q_mixed[1])
    show(out, MIME"text/html"(), s_1q_mixed)
    html = String(take!(out))
    @test occursin("Single-qubit state", html)

    reg_2q = Register(2)
    initialize!((reg_2q[1], reg_2q[2]), X1⊗Z1+Z1⊗X1)
    s_2q = QuantumSavory.stateof(reg_2q[1])
    show(out, MIME"text/html"(), s_2q)
    html = String(take!(out))
    @test occursin("Two-qubit state", html)

    reg_2q_mixed = Register(2)
    initialize!((reg_2q_mixed[1], reg_2q_mixed[2]), dm(QuantumSavory.quantumstate(s_2q)))
    s_2q_mixed = QuantumSavory.stateof(reg_2q_mixed[1])
    show(out, MIME"text/html"(), s_2q_mixed)
    html = String(take!(out))
    @test occursin("Two-qubit state", html)

    reg_3q = Register(3)
    initialize!((reg_3q[1], reg_3q[2], reg_3q[3]), Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2)
    s_3q = QuantumSavory.stateof(reg_3q[1])
    show(out, MIME"text/html"(), s_3q)
    html = String(take!(out))
    @test occursin("3-qubit state", html)
    @test occursin("Amplitudes", html)

    reg_3q_mixed = Register(3)
    initialize!((reg_3q_mixed[1], reg_3q_mixed[2], reg_3q_mixed[3]), dm(QuantumSavory.quantumstate(s_3q)))
    s_3q_mixed = QuantumSavory.stateof(reg_3q_mixed[1])
    show(out, MIME"text/html"(), s_3q_mixed)
    html = String(take!(out))
    @test occursin("3-qubit state", html)
    @test occursin("Diagonal entries", html)

    reg_6q = Register(6)
    initialize!((reg_6q[1], reg_6q[2], reg_6q[3], reg_6q[4], reg_6q[5], reg_6q[6]), Z1⊗Z1⊗Z1⊗Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2⊗Z2⊗Z2⊗Z2)
    s_6q = QuantumSavory.stateof(reg_6q[1])
    show(out, MIME"text/html"(), s_6q)
    html = String(take!(out))
    @test occursin("6-qubit state", html)
    @test occursin("Top-8 amplitudes", html)

    reg_6q_mixed = Register(6)
    initialize!((reg_6q_mixed[1], reg_6q_mixed[2], reg_6q_mixed[3], reg_6q_mixed[4], reg_6q_mixed[5], reg_6q_mixed[6]), dm(QuantumSavory.quantumstate(s_6q)))
    s_6q_mixed = QuantumSavory.stateof(reg_6q_mixed[1])
    show(out, MIME"text/html"(), s_6q_mixed)
    html = String(take!(out))
    @test occursin("6-qubit state", html)
    @test occursin("Top-8 probabilities", html)

    QuantumSavory.stateshow(out, MIME"text/html"(), UnknownState(), nothing)
    html = String(take!(out))
    @test occursin("does not support rich visualization", html)

    reg = Register(1, CliffordRepr())
    initialize!(reg[1], X1)
    show(out, MIME"text/html"(), QuantumSavory.stateof(reg[1]))
    html = String(take!(out))
    @test occursin("Stabilizer state", html)
end
