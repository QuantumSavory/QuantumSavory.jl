using Test
using QuantumSavory
using QuantumSavory: stateshow

struct UnknownState end

@testset "StateRef text/plain display" begin
    out = IOBuffer()

    # 1-qubit pure
    stateshow(out, MIME"text/plain"(), X1, nothing)
    txt = String(take!(out))
    @test occursin("Single-qubit state", txt)

    # 1-qubit mixed
    stateshow(out, MIME"text/plain"(), dm(X1), nothing)
    txt = String(take!(out))
    @test occursin("Single-qubit state", txt)
    @test occursin("Density matrix", txt)

    # 2-qubit pure
    stateshow(out, MIME"text/plain"(), X1⊗Z1+Z1⊗X1, nothing)
    txt = String(take!(out))
    @test occursin("Two-qubit state", txt)

    # 2-qubit mixed
    stateshow(out, MIME"text/plain"(), dm(X1⊗Z1), nothing)
    txt = String(take!(out))
    @test occursin("Two-qubit state", txt)

    # 3-qubit pure (nq pure)
    stateshow(out, MIME"text/plain"(), Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2, nothing)
    txt = String(take!(out))
    @test occursin("3-qubit pure state", txt)

    # 3-qubit mixed (nq mixed)
    stateshow(out, MIME"text/plain"(), dm(Z1⊗Z1⊗Z1), nothing)
    txt = String(take!(out))
    @test occursin("3-qubit mixed state", txt)

    # Large pure (6-qubit)
    stateshow(out, MIME"text/plain"(), Z1⊗Z1⊗Z1⊗Z1⊗Z1⊗Z1, nothing)
    txt = String(take!(out))
    @test occursin("6-qubit state", txt)

    # Large mixed (6-qubit)
    stateshow(out, MIME"text/plain"(), dm(Z1⊗Z1⊗Z1⊗Z1⊗Z1⊗Z1), nothing)
    txt = String(take!(out))
    @test occursin("6-qubit state", txt)
    @test occursin("Top-8 probabilities", txt)

    # Generic
    stateshow(out, MIME"text/plain"(), UnknownState(), nothing)
    txt = String(take!(out))
    @test occursin("State of type", txt)

    # Clifford
    reg = Register(1, CliffordRepr())
    initialize!(reg[1], X1)
    stateshow(out, MIME"text/plain"(), QuantumSavory.stateof(reg[1]), nothing)
    txt = String(take!(out))
    @test occursin("Stabilizer state", txt)
end

@testset "StateRef text/html display" begin
    out = IOBuffer()

    # 1-qubit pure
    stateshow(out, MIME"text/html"(), X1, nothing)
    html = String(take!(out))
    @test occursin("Single-qubit state", html)

    # 1-qubit mixed
    stateshow(out, MIME"text/html"(), dm(X1), nothing)
    html = String(take!(out))
    @test occursin("Single-qubit state", html)

    # 2-qubit pure
    stateshow(out, MIME"text/html"(), X1⊗Z1+Z1⊗X1, nothing)
    html = String(take!(out))
    @test occursin("Two-qubit state", html)

    # 2-qubit mixed
    stateshow(out, MIME"text/html"(), dm(X1⊗Z1), nothing)
    html = String(take!(out))
    @test occursin("Two-qubit state", html)

    # 3-qubit pure
    stateshow(out, MIME"text/html"(), Z1⊗Z1⊗Z1 + Z2⊗Z2⊗Z2, nothing)
    html = String(take!(out))
    @test occursin("3-qubit state", html)
    @test occursin("Amplitudes", html)

    # 3-qubit mixed
    stateshow(out, MIME"text/html"(), dm(Z1⊗Z1⊗Z1), nothing)
    html = String(take!(out))
    @test occursin("3-qubit state", html)
    @test occursin("Diagonal entries", html)

    # Large pure (6-qubit)
    stateshow(out, MIME"text/html"(), Z1⊗Z1⊗Z1⊗Z1⊗Z1⊗Z1, nothing)
    html = String(take!(out))
    @test occursin("6-qubit state", html)
    @test occursin("Top-8 amplitudes", html)

    # Large mixed (6-qubit)
    stateshow(out, MIME"text/html"(), dm(Z1⊗Z1⊗Z1⊗Z1⊗Z1⊗Z1), nothing)
    html = String(take!(out))
    @test occursin("6-qubit state", html)
    @test occursin("Top-8 probabilities", html)

    # Generic
    stateshow(out, MIME"text/html"(), UnknownState(), nothing)
    html = String(take!(out))
    @test occursin("does not support rich visualization", html)

    # Clifford
    reg = Register(1, CliffordRepr())
    initialize!(reg[1], X1)
    stateshow(out, MIME"text/html"(), QuantumSavory.stateof(reg[1]), nothing)
    html = String(take!(out))
    @test occursin("Stabilizer state", html)
end
