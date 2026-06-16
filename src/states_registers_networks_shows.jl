# ─────────────────────────────────────────────────────────────────────────────
# Rich display for register states  –  closes #401
# ─────────────────────────────────────────────────────────────────────────────

"""
Maximum number of qubits for which a full density-matrix or amplitude table is
generated during display.  States larger than this threshold fall back to a
compact one-line summary.  Tunable without breaking the display contract.
"""

const RICH_DISPLAY_MAX_DENSE_QUBITS = 5

"""
Maximum number of basis-state rows shown in the top-probability tables.
Prevents display from materialising an exponentially large table even within
the dense range.
"""
const RICH_DISPLAY_TOP_K = 8

# ── private helpers ───────────────────────────────────────────────────────────

# Bloch vector from a 2×2 complex density-matrix array.
# Derivation: ⟨σₓ⟩=2Re(ρ₀₁), ⟨σᵧ⟩=−2Im(ρ₀₁), ⟨σ_z⟩=ρ₀₀−ρ₁₁
function _bloch_from_dm2(ρ::AbstractMatrix{<:Complex})
    bx = 2real(ρ[1, 2])
    by = -2imag(ρ[1, 2])
    bz = real(ρ[1, 1]) - real(ρ[2, 2])
    return (bx, by, bz)
end

# Von Neumann entropy in nats from a list of eigenvalues.
function _vn_entropy(λs)
    return -sum(λ * log(max(λ, 0.0) + 1e-300) for λ in λs if λ > 1e-14; init=0.0)
end

# Purity = Tr(ρ²) from eigenvalues.
_purity(λs) = sum(λ^2 for λ in λs; init=0.0)

# Label the i-th basis state (0-indexed) for n qubits.
function _ket_label(i::Int, n::Int)
    bits = digits(i, base=2, pad=n) |> reverse
    return "|" * join(string.(bits)) * "⟩"
end

# Top-K basis states by diagonal probability.
function _top_k_basis(ρ_data::AbstractMatrix, n::Int, k::Int=RICH_DISPLAY_TOP_K)
    probs = real.(LinearAlgebra.diag(ρ_data))
    ord   = sortperm(probs, rev=true)
    rows  = [(label=_ket_label(ord[i] - 1, n), prob=probs[ord[i]])
              for i in 1:min(k, length(ord)) if probs[ord[i]] > 1e-10]
    return rows
end

# Wootters concurrence of a 4×4 two-qubit density matrix (PRA 78(4), 2156, 1998).
function _concurrence(ρ::AbstractMatrix{<:Complex})
    σy    = ComplexF64[0 -im; im 0]
    R     = kron(σy, σy)                    # spin-flip operator
    ρ̃     = R * conj.(ρ) * R               # spin-flipped state
    M     = ρ * ρ̃
    λs    = sort(max.(0.0, real.(LinearAlgebra.eigvals(M))), rev=true)
    sqrts = sqrt.(λs)
    return max(0.0, sqrts[1] - sqrts[2] - sqrts[3] - sqrts[4])
end

# Overlap with each Bell state: ⟨B|ρ|B⟩  (fidelity, a real number in [0,1]).
function _bell_fidelities(ρ::AbstractMatrix{<:Complex})
    r2 = 1.0 / √2
    bells = (
        ("Φ⁺", ComplexF64[r2,  0,  0,  r2]),
        ("Φ⁻", ComplexF64[r2,  0,  0, -r2]),
        ("Ψ⁺", ComplexF64[ 0, r2, r2,   0]),
        ("Ψ⁻", ComplexF64[ 0, r2,-r2,   0]),
    )
    return [(label, real(dot(v, ρ * v))) for (label, v) in bells]
end

# Reduced single-qubit density matrices via partial trace.
function _two_qubit_marginals(state)
    # ptrace(state, [2]) keeps qubit 1 (traces out qubit 2)
    ρ_A = ptrace(state, [2]).data   # 2×2 DM for qubit A
    # ptrace(state, [1]) keeps qubit 2 (traces out qubit 1)
    ρ_B = ptrace(state, [1]).data   # 2×2 DM for qubit B
    return ρ_A, ρ_B
end

# Simple ASCII Bloch-sphere sketch: XZ projection with ●/○/◉ marking the state.
# Works in any plain terminal without Makie.
function _ascii_bloch(bx, by, bz)
    # 5-row × 11-col grid; centre at (row=3, col=6)
    grid = collect.(["           ",
                     "     +Z    ",
                     "  ---+---  ",
                     "     -Z    ",
                     "           "])
    mark = abs(by) < 0.1 ? '◉' : by > 0 ? '●' : '○'
    # scale: col ∈ [1,11] from bx ∈ [-1,1]; row ∈ [1,5] from bz ∈ [1,-1]
    col = clamp(round(Int, 6 + 4.5 * bx), 1, 11)
    row = clamp(round(Int, 3 - 2.0 * bz), 1, 5)
    grid[row][col] = mark
    return join(join.(grid), "\n")
end

# ── QuantumOpticsBase text display ────────────────────────────────────────────

# The internal workhorse: render a QuantumOpticsBase state (Ket or DenseOperator)
# to io as plain text.  Called by the show override below.
function _show_qo_text(io::IO, state)
    # normalise to density matrix
    ρ_op = (state isa Operator) ? state : dm(state)
    ρ    = ρ_op.data

    N    = size(ρ, 1)
    n    = round(Int, log2(N))
    # guard: only handle pure power-of-2 Hilbert spaces here
    if N != (1 << n)
        print(io, "(QuantumOptics state on non-qubit space of dimension $N)")
        return
    end

    λraw = real.(LinearAlgebra.eigvals(ρ))
    λs   = sort(max.(0.0, λraw), rev=true)
    λs ./= max(sum(λs), 1e-14)          # renormalise numerical noise
    p    = _purity(λs)
    S    = _vn_entropy(λs)

    println(io, "QuantumOptics state  [n=$n qubit$(n==1 ? "" : "s")]")
    @printf(io, "  purity  = %.6f\n", p)
    @printf(io, "  entropy = %.6f  nat\n", S)

    if n == 1
        bx, by, bz = _bloch_from_dm2(ρ)
        @printf(io, "  Bloch   = (⟨X⟩=%.4f, ⟨Y⟩=%.4f, ⟨Z⟩=%.4f)\n", bx, by, bz)
        println(io)
        println(io, "  Bloch sphere  (XZ projection; ●=+Y side, ○=−Y side, ◉=in-plane)")
        for ln in split(_ascii_bloch(bx, by, bz), '\n')
            println(io, "    ", ln)
        end
        println(io)
        println(io, "  Density matrix:")
        @printf(io, "    ┌ %+.4f%+.4fi   %+.4f%+.4fi ┐\n",
                real(ρ[1,1]), imag(ρ[1,1]), real(ρ[1,2]), imag(ρ[1,2]))
        @printf(io, "    └ %+.4f%+.4fi   %+.4f%+.4fi ┘\n",
                real(ρ[2,1]), imag(ρ[2,1]), real(ρ[2,2]), imag(ρ[2,2]))

    elseif n == 2
        C      = _concurrence(ρ)
        @printf(io, "  concurrence = %.6f  (%s)\n",
                C, C < 1e-4 ? "separable" : C > 0.99 ? "maximally entangled" : "partially entangled")

        ρ_A, ρ_B = _two_qubit_marginals(ρ_op)
        bxA, byA, bzA = _bloch_from_dm2(ρ_A)
        bxB, byB, bzB = _bloch_from_dm2(ρ_B)
        @printf(io, "  qubit A  ⟨X⟩=%+.4f  ⟨Y⟩=%+.4f  ⟨Z⟩=%+.4f\n", bxA, byA, bzA)
        @printf(io, "  qubit B  ⟨X⟩=%+.4f  ⟨Y⟩=%+.4f  ⟨Z⟩=%+.4f\n", bxB, byB, bzB)
        println(io)
        println(io, "  Bell-state fidelities:")
        for (label, f) in _bell_fidelities(ρ)
            @printf(io, "    |%s⟩  %.4f\n", label, f)
        end
        println(io)
        println(io, "  Top basis probabilities:")
        for row in _top_k_basis(ρ, n)
            @printf(io, "    %s  %.4f\n", row.label, row.prob)
        end

    elseif n ≤ RICH_DISPLAY_MAX_DENSE_QUBITS
        println(io, "\n  Top-$(RICH_DISPLAY_TOP_K) basis probabilities:")
        for row in _top_k_basis(ρ, n)
            @printf(io, "    %s  %.4f\n", row.label, row.prob)
        end

    else
        println(io, "  (dense display suppressed for n=$n > $RICH_DISPLAY_MAX_DENSE_QUBITS)")
        println(io, "  Use `stateof(regref)` to access the underlying state object.")
    end
end

# ── QuantumOpticsBase HTML display ────────────────────────────────────────────

function _show_qo_html(io::IO, state)
    ρ_op = (state isa Operator) ? state : dm(state)
    ρ    = ρ_op.data
    N    = size(ρ, 1)
    n    = round(Int, log2(N))
    if N != (1 << n)
        print(io, "<code>QuantumOptics state on non-qubit space, dim=$N</code>")
        return
    end

    λraw = real.(LinearAlgebra.eigvals(ρ))
    λs   = sort(max.(0.0, λraw), rev=true)
    λs ./= max(sum(λs), 1e-14)
    p    = _purity(λs)
    S    = _vn_entropy(λs)

    # shared header
    print(io, """
    <div class="qs-state-display" style="font-family:monospace;padding:0.5em;border-left:3px solid #7b5ea7">
    <strong>QuantumOptics state</strong> &nbsp;[n=$n qubit$(n==1 ? "" : "s")]<br>
    <table style="border-collapse:collapse;margin:0.4em 0">
    <tr><td style="padding:0 1em 0 0">purity</td><td>$(round(p,digits=6))</td></tr>
    <tr><td style="padding:0 1em 0 0">entropy</td><td>$(round(S,digits=6)) nat</td></tr>
    """)

    if n == 1
        bx, by, bz = _bloch_from_dm2(ρ)
        @printf(io, "<tr><td>Bloch</td><td>(⟨X⟩=%+.4f, ⟨Y⟩=%+.4f, ⟨Z⟩=%+.4f)</td></tr>\n",
                bx, by, bz)
        print(io, "</table>")
        # 2×2 density matrix table
        print(io, """
        <details><summary>Density matrix</summary>
        <table style="border-collapse:collapse;margin:0.3em 0">
        """)
        for r in 1:2
            print(io, "<tr>")
            for c in 1:2
                z = ρ[r, c]
                print(io, "<td style='padding:2px 8px;border:1px solid #ccc'>",
                      @sprintf("%+.4f%+.4fi", real(z), imag(z)), "</td>")
            end
            print(io, "</tr>")
        end
        print(io, "</table></details>")

    elseif n == 2
        C = _concurrence(ρ)
        @printf(io, "<tr><td>concurrence</td><td>%.6f</td></tr>\n", C)
        ρ_A, ρ_B = _two_qubit_marginals(ρ_op)
        bxA, byA, bzA = _bloch_from_dm2(ρ_A)
        bxB, byB, bzB = _bloch_from_dm2(ρ_B)
        @printf(io, "<tr><td>qubit A Bloch</td><td>(%+.4f, %+.4f, %+.4f)</td></tr>\n", bxA, byA, bzA)
        @printf(io, "<tr><td>qubit B Bloch</td><td>(%+.4f, %+.4f, %+.4f)</td></tr>\n", bxB, byB, bzB)
        print(io, "</table>")
        # Bell fidelities
        print(io, "<details><summary>Bell-state fidelities</summary><table style='border-collapse:collapse'>")
        for (label, f) in _bell_fidelities(ρ)
            @printf(io, "<tr><td style='padding:2px 8px'>|%s⟩</td><td style='padding:2px 8px'>%.4f</td></tr>", label, f)
        end
        print(io, "</table></details>")
        # top-K
        print(io, "<details><summary>Top basis probabilities</summary><table style='border-collapse:collapse'>")
        for row in _top_k_basis(ρ, n)
            @printf(io, "<tr><td style='padding:2px 8px'>%s</td><td style='padding:2px 8px'>%.4f</td></tr>", row.label, row.prob)
        end
        print(io, "</table></details>")

    elseif n ≤ RICH_DISPLAY_MAX_DENSE_QUBITS
        print(io, "</table>")
        print(io, "<details><summary>Top-$(RICH_DISPLAY_TOP_K) basis probabilities</summary><table>")
        for row in _top_k_basis(ρ, n)
            @printf(io, "<tr><td style='padding:2px 8px'>%s</td><td>%.4f</td></tr>", row.label, row.prob)
        end
        print(io, "</table></details>")
    else
        @printf(io, "<tr><td colspan='2'><em>dense display suppressed (n=%d &gt; %d)</em></td></tr>",
                n, RICH_DISPLAY_MAX_DENSE_QUBITS)
        print(io, "</table>")
    end

    print(io, "\n</div>")
end

# ── QuantumClifford text/HTML helpers ─────────────────────────────────────────

function _show_qc_text(io::IO, state)
    # Re-use QuantumClifford's own text representation of the stabilizer tableau.
    println(io, "QuantumClifford stabilizer state  [n=$(QuantumClifford.nqubits(state)) qubit$(QuantumClifford.nqubits(state)==1 ? "" : "s")]")
    println(io, "  Stabilizer generators:")
    tab = QuantumClifford.stabilizerview(state)
    for g in tab
        println(io, "    ", g)
    end
end

function _show_qc_html(io::IO, state)
    n = QuantumClifford.nqubits(state)
    print(io, """
    <div class="qs-state-display" style="font-family:monospace;padding:0.5em;border-left:3px solid #5e9b6a">
    <strong>QuantumClifford state</strong> &nbsp;[$n qubit$(n==1 ? "" : "s")]<br>
    Stabilizer generators:<br><code>
    """)
    for g in QuantumClifford.stabilizerview(state)
        print(io, "  ", g, "<br>")
    end
    print(io, "</code></div>")
end

# ── Hook into QuantumSavory's StateRef show ───────────────────────────────────
# Add specialised dispatch methods. The fallback (existing code) stays untouched.

# Detect QuantumOptics state types via duck typing so we don't introduce a
# hard compile-time dependency on the package name.
_is_qo_state(s) = applicable(dm, s) || (applicable(basis, s) && hasproperty(s, :data))
_is_qc_state(s) = applicable(QuantumClifford.stabilizerview, s) || applicable(QuantumClifford.nqubits, s)

function Base.show(io::IO, s::StateRef)
    st = s.state[]
    if st === nothing
        print(io, "StateRef (empty slot)")
    elseif _is_qo_state(st)
        _show_qo_text(io, st)
    elseif _is_qc_state(st)
        _show_qc_text(io, st)
    else
        print(io, "StateRef(", typeof(st), ")")
    end
end

function Base.show(io::IO, ::MIME"text/html", s::StateRef)
    st = s.state[]
    if st === nothing
        print(io, "<em>(empty register slot)</em>")
    elseif _is_qo_state(st)
        _show_qo_html(io, st)
    elseif _is_qc_state(st)
        _show_qc_html(io, st)
    else
        print(io, "<code>$(typeof(st)) — no rich HTML display</code>")
    end
end