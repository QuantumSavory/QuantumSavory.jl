using Test
import QuantumSavory
import QuantumOptics: SpinBasis, spinup, spindown, tensor, DenseOperator
import QuantumSavory: stateof, initialize!

@testset "Rich StateRef text/HTML display" begin

    b = SpinBasis(1//2)

    # ── 1-qubit pure state ──────────────────────────────────────────────
    reg1 = QuantumSavory.Register(1)
    initialize!(reg1[1], spinup(b))
    txt1 = sprint(show, stateof(reg1[1]))
    @test occursin("QuantumOptics", txt1)
    @test occursin("purity",  txt1)
    @test occursin("Bloch",   txt1)
    @test !occursin("does not support", txt1)

    html1 = repr(MIME"text/html"(), stateof(reg1[1]))
    @test occursin("purity",           html1)
    @test occursin("qs-state-display", html1)
    @test !occursin("does not support", html1)

    # ── 1-qubit mixed state ──────────────────────────────────────────────
    reg_m = QuantumSavory.Register(1)
    initialize!(reg_m[1], DenseOperator(b, ComplexF64[0.6 0; 0 0.4]))
    txt_m = sprint(show, stateof(reg_m[1]))
    @test occursin("purity",  txt_m)
    @test occursin("entropy", txt_m)

    # ── 2-qubit Bell state ───────────────────────────────────────────────
    bell = (tensor(spinup(b), spinup(b)) + tensor(spindown(b), spindown(b))) / √2
    reg2 = QuantumSavory.Register(2)
    initialize!((reg2[1], reg2[2]), bell)
    txt2 = sprint(show, stateof(reg2[1]))
    @test occursin("concurrence", txt2)
    @test occursin("Bell",        txt2)
    @test !occursin("does not support", txt2)

    html2 = repr(MIME"text/html"(), stateof(reg2[1]))
    @test occursin("concurrence", html2)
    @test !occursin("does not support", html2)

    # ── 3-qubit product state ────────────────────────────────────────────
    ψ3   = tensor(spinup(b), spinup(b), spinup(b))
    reg3 = QuantumSavory.Register(3)
    initialize!((reg3[1], reg3[2], reg3[3]), ψ3)
    txt3 = sprint(show, stateof(reg3[1]))
    @test occursin("|000⟩", txt3)
    @test !occursin("does not support", txt3)

    # ── 6-qubit: compact fallback ────────────────────────────────────────
    ψ6   = tensor([spinup(b) for _ in 1:6]...)
    reg6 = QuantumSavory.Register(6)
    initialize!(Tuple(reg6[i] for i in 1:6), ψ6)
    txt6 = sprint(show, stateof(reg6[1]))
    @test occursin("suppressed", txt6) || occursin("n=6", txt6)
    @test !occursin("does not support", txt6)

    println("All text/HTML display tests passed ✓")
end
