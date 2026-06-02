using Test
using QuantumSavory
using Gabs

const GABS_QBLOCK = GabsRepr(QuadBlockBasis)

function show_plain(stateref)
    io = IOBuffer()
    show(io, stateref)
    return String(take!(io))
end

function show_html(stateref)
    io = IOBuffer()
    show(io, MIME"text/html"(), stateref)
    return String(take!(io))
end

@testset "Gabs Gaussian state display" begin
    @testset "one-mode coherent state" begin
        reg = Register([Qumode()], [GABS_QBLOCK])
        initialize!(reg[1], CoherentState(0.5 + 0.2im))
        sref = QuantumSavory.stateof(reg[1])
        plain = show_plain(sref)
        html = show_html(sref)

        @test occursin("Gaussian state of 1 mode", plain)
        @test occursin("First moments", plain)
        @test occursin("Purity:", plain)
        @test !occursin("does not support rich visualization", plain)
        @test !occursin("does not support rich visualization", html)
        @test occursin("GaussianState", html)
        @test occursin("<table", html)
        @test !occursin("Per-mode marginals", plain)
    end

    @testset "two-mode squeezed state" begin
        reg = Register(fill(Qumode(), 2), fill(GABS_QBLOCK, 2))
        initialize!(reg[1:2], TwoSqueezedState(0.45))
        sref = QuantumSavory.stateof(reg[1])
        plain = show_plain(sref)
        html = show_html(sref)

        @test occursin("Gaussian state of 2 modes", plain)
        @test occursin("Covariance matrix: 4×4", plain)
        @test occursin("Per-mode marginals", plain)
        @test occursin("mode 1:", plain)
        @test occursin("mode 2:", plain)
        @test !occursin("does not support rich visualization", html)
        @test occursin("Per-mode marginals", html)
    end

    @testset "stateshow on native GaussianState" begin
        state = express(TwoSqueezedState(0.2), GABS_QBLOCK)
        io = IOBuffer()
        QuantumSavory.stateshow(io, MIME"text/plain"(), state, nothing)
        out = String(take!(io))
        @test occursin("Gaussian state of 2 modes", out)
        io = IOBuffer()
        QuantumSavory.stateshow(io, MIME"text/html"(), state, nothing)
        html = String(take!(io))
        @test occursin("quantumsavory_numericalstate", html)
        @test occursin("<table", html)
    end
end
