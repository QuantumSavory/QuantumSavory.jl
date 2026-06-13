using Test
using QuantumSavory

@testset "StateRef text/plain display" begin

    out = IOBuffer()

    reg = Register(1)
    initialize!(reg[1], X1)
    state = QuantumSavory.stateof(reg[1])
    show(out, state)
    txt = String(take!(out))
    @test occursin("Single-qubit state", txt)
    @test occursin("Bloch vector", txt)
    @test occursin("Purity", txt)
    @test !occursin("does not support rich visualization", txt)

    reg = Register(1, CliffordRepr())
    initialize!(reg[1], X1)
    state = QuantumSavory.stateof(reg[1])
    show(out, state)
    txt = String(take!(out))
    @test occursin("Stabilizer", txt)
    @test !occursin("does not support rich visualization", txt)

    reg1 = Register(1)
    reg2 = Register(1)
    net = RegisterNet([reg1, reg2])
    initialize!((reg1[1], reg2[1]), X1⊗Z1+Z1⊗X1)
    state = QuantumSavory.stateof(reg1[1])
    show(out, state)
    txt = String(take!(out))
    @test occursin("Two-qubit state", txt)
    @test occursin("Density matrix", txt)
    @test occursin("Qubit 1 reduced", txt)
    @test !occursin("does not support rich visualization", txt)

    reg = Register(3)
    initialize!((reg[1], reg[2], reg[3]), X1⊗Z1⊗X1)
    state = QuantumSavory.stateof(reg[1])
    show(out, state)
    txt = String(take!(out))
    @test occursin("3-qubit", txt)
    @test occursin("Top amplitudes", txt)
    @test !occursin("does not support rich visualization", txt)

end

@testset "StateRef text/html display" begin

    out = IOBuffer()

    reg = Register(1)
    initialize!(reg[1], X1)
    state = QuantumSavory.stateof(reg[1])
    show(out, MIME"text/html"(), state)
    html = String(take!(out))
    @test occursin("Single-qubit state", html)
    @test occursin("Bloch vector", html)
    @test occursin("<table", html)
    @test !occursin("does not support rich visualization", html)

    reg = Register(1, CliffordRepr())
    initialize!(reg[1], X1)
    state = QuantumSavory.stateof(reg[1])
    show(out, MIME"text/html"(), state)
    html = String(take!(out))
    @test occursin("Stabilizer state", html)
    @test occursin("Generator", html)
    @test !occursin("does not support rich visualization", html)

    reg1 = Register(1)
    reg2 = Register(1)
    net = RegisterNet([reg1, reg2])
    initialize!((reg1[1], reg2[1]), X1⊗Z1+Z1⊗X1)
    state = QuantumSavory.stateof(reg1[1])
    show(out, MIME"text/html"(), state)
    html = String(take!(out))
    @test occursin("Two-qubit state", html)
    @test occursin("Purity", html)
    @test occursin("Qubit 1", html)
    @test !occursin("does not support rich visualization", html)

    reg = Register(3)
    initialize!((reg[1], reg[2], reg[3]), X1⊗Z1⊗X1)
    state = QuantumSavory.stateof(reg[1])
    show(out, MIME"text/html"(), state)
    html = String(take!(out))
    @test occursin("3-qubit state", html)
    @test occursin("Amplitudes", html)
    @test !occursin("does not support rich visualization", html)

end
