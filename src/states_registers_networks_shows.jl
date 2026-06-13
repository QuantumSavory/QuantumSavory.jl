function Base.show(io::IO, s::StateRef)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "State $(typeof(s.state[]).name.module) of size $(nsubsystems(s.state[]))")
    else
        print(io, "State containing $(nsubsystems(s.state[])) subsystems in $(typeof(s.state[]).name.module) implementation")
        print(io, "\n  In registers:")
        for (i,r) in zip(s.registerindices, s.registers)
            if isnothing(r)
                print(io, "\n    not used")
            else
                print(IOContext(io, :compact => true), "\n    ",(r[i]))
            end
        end
        print(io, "\n  State summary:\n    ")
        stateshow(io, MIME"text/plain"(), quantumstate(s), s)
    end
end

function stateshow(io, ::MIME"text/plain", state, stateref)
    print(io, "State of type $(typeof(state))")
end



function Base.show(io::IO, r::Register)
    regname = namestr(r; useobjectid=false)
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "Register $(regname)")
    else
        print(io, "Register $(regname) with $(length(r.traits)) slots") # TODO make this length call prettier
        print(io, ": [ ")
        print(io, join(string.(typeof.(r.traits)), " | "))
        print(io, " ]")
        print(io, "\n  Slots:")
        for (i,s) in zip(r.stateindices, r.staterefs)
            if isnothing(s)
                print(io, "\n    nothing")
            else
                print(io, "\n    Subsystem $(i) of $(typeof(s.state[]).name.module).$(typeof(s.state[]).name.name) $(objectid(s.state[]))")
            end
        end
    end
end

function Base.show(io::IO, net::RegisterNet)
    print(io, "A network of $(length(net.registers)) registers in a graph of $(length(edges(net.graph))) edges\n")
end

function Base.show(io::IO, r::RegRef)
    regstr = namestr(parent(r))
    if get(io, :compact, false) | haskey(io, :typeinfo)
        print(io, "$(regstr).$(r.idx)")
    else
        print(io, "Slot $(r.idx)/$(length(r.reg.traits)) of Register $(regstr)") # TODO make this length call prettier
        print(io, "\nContent:")
        i,s = r.reg.stateindices[r.idx], r.reg.staterefs[r.idx]
        if isnothing(s)
            print(io, "\n    nothing")
        else
            print(io, "\n    $(i) @ ")
            print(IOContext(io, :compact => true), s)
        end
    end
end

"""The human-readable name or the simulated object as a string or `nothing`."""
function name end
name(r::Register) = isnothing(r.netparent[]) ? nothing : get(r.netparent[].names, r.netindex[], nothing)
name(r::RegisterNet) = r.name
name(::Nothing) = nothing
"""The human-readable name or the simulated object as a string (potentially empty)."""
function namestr(n)
    return isnothing(name(n)) ? "" : name(n)
end
function namestr(reg::Register; useobjectid=true)
    net = parent(reg)
    if isnothing(net)
        useobjectid ? "$(objectid(reg))" : ""
    else
        regname = name(reg)
        if isnothing(regname)
            netname = name(net)
            if isnothing(netname)
                "$(parentindex(reg))"
            else
                "$netname[$(parentindex(reg))]"
            end
        else
            "$regname(#$(parentindex(reg)))"
        end
    end
end

function Base.show(io::IO, m::MIME"text/html", r::RegRef)
    print(io,"""
    <div class="quantumsavory_show quantumsavory_regref">
    """)
    isnothing(r.reg.netparent[]) || print(io,"""
    <span class"quantumsavory_regref_netname">$(namestr(r.reg.netparent[]))</span>
    <span class"quantumsavory_regref_regindex">$(r.reg.netindex[])</span>
    <span class"quantumsavory_regref_name">$(namestr(r.reg))</span>
    """)
    print(io,"""
    <span class"quantumsavory_regref_slotindex">$(r.idx)</span>
    </div>
    """)
end

function Base.show(io::IO, m::MIME"text/html", s::StateRef)
    print(io,"""
    <div class="quantumsavory_show quantumsavory_stateref">
    <div class="quantumsavory_stateref_regrefs">
    <ol>
    """)
    for rr in slots(s)
        print(io, "<li>")
        show(io, m, rr)
        print(io, "</li>")
    end
    print(io,"""
    </ol>
    </div>
    <div class="quantumsavory_stateref_state">
    """)
    stateshow(io, m, quantumstate(s), s)
    print(io,"""
    </div>
    </div>
    """)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy."""
function stateshow(io, ::MIME"text/html", state, stateref)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_unknown">
    state of type <pre class="quantumsavory_typename quantumsavory_numericalstate_typename">$(typeof(state))</pre> does not support rich visualization in HTML
    </div>
    """)
end

function _fmt(z::Complex; digits=4)
    r, i = round(real(z), digits=digits), round(imag(z), digits=digits)
    if abs(i) < 10.0^(-digits)
        return string(r)
    elseif abs(r) < 10.0^(-digits)
        return string(i, "im")
    else
        sign = i >= 0 ? "+" : "-"
        return string(r, sign, abs(i), "im")
    end
end

_fmt(x::Real; digits=4) = string(round(x, digits=digits))

const _DENSE_VIS_CUTOFF = 5

# --- text/plain for QuantumOptics kets ---

function stateshow(io, ::MIME"text/plain", state::Ket, stateref)
    _is_qubit_state(state) || return _stateshow_generic_text(io, state)
    n = _nqubits_qo(state)
    ρ = _to_dm(state)
    if n == 1
        _show_text_1q(io, ρ)
    elseif n == 2
        _show_text_2q(io, ρ)
    elseif n <= _DENSE_VIS_CUTOFF
        _show_text_nq_pure(io, state, n)
    else
        _show_text_large(io, state, ρ, n)
    end
end

function stateshow(io, ::MIME"text/plain", state::Operator, stateref)
    _is_qubit_state(state) || return _stateshow_generic_text(io, state)
    n = _nqubits_qo(state)
    if n == 1
        _show_text_1q(io, state)
    elseif n == 2
        _show_text_2q(io, state)
    elseif n <= _DENSE_VIS_CUTOFF
        _show_text_nq_mixed(io, state, n)
    else
        _show_text_large(io, nothing, state, n)
    end
end

function stateshow(io, ::MIME"text/plain", state::QuantumClifford.MixedDestabilizer, stateref)
    nq = QuantumClifford.nqubits(state)
    println(io, "Stabilizer state: $nq qubits")
    println(io, "Stabilizer generators:")
    for s in _clifford_stabilizer_strings(state)
        println(io, "  ", s)
    end
end

function _stateshow_generic_text(io, state)
    print(io, "State of type $(typeof(state))")
end

function _show_text_1q(io, ρ)
    rx, ry, rz = _bloch_vector(ρ)
    ex, ey, ez = _pauli_expectations_1q(ρ)
    p = _purity(ρ)
    S = _von_neumann_entropy(ρ)
    println(io, "Single-qubit state")
    println(io, "  Bloch vector: ($(_fmt(rx)), $(_fmt(ry)), $(_fmt(rz)))")
    println(io, "  ⟨X⟩=$(_fmt(ex))  ⟨Y⟩=$(_fmt(ey))  ⟨Z⟩=$(_fmt(ez))")
    println(io, "  Purity: $(_fmt(p))")
    println(io, "  Entropy: $(_fmt(S)) bits")
    m = _dm_matrix(ρ)
    println(io, "  Density matrix:")
    println(io, "    ⎡ $(_fmt(m[1, 1]))  $(_fmt(m[1, 2])) ⎤")
    print(io,   "    ⎣ $(_fmt(m[2, 1]))  $(_fmt(m[2, 2])) ⎦")
end

function _show_text_2q(io, ρ)
    p = _purity(ρ)
    S = _von_neumann_entropy(ρ)
    println(io, "Two-qubit state")
    println(io, "  Purity: $(_fmt(p))")
    println(io, "  Entropy: $(_fmt(S)) bits")
    m = _dm_matrix(ρ)
    labels = _basis_labels(2)
    println(io, "  Density matrix (computational basis):")
    println(io, "       ", join(lpad.(labels, 12)))
    for (i, li) in enumerate(labels)
        row = join([lpad(_fmt(m[i,j]), 12) for j in 1:4])
        println(io, "    $li $row")
    end
    for q in 1:2
        ρ_red = _reduced_dm(ρ, q)
        bx, by, bz = _bloch_vector(ρ_red)
        println(io, "  Qubit $q reduced: ⟨X⟩=$(_fmt(bx)) ⟨Y⟩=$(_fmt(by)) ⟨Z⟩=$(_fmt(bz)) purity=$(_fmt(_purity(ρ_red)))")
    end
end

function _show_text_nq_pure(io, ψ, n)
    S = _von_neumann_entropy(_to_dm(ψ))
    println(io, "$n-qubit pure state")
    println(io, "  Entropy: $(_fmt(S)) bits")
    k = min(2^n, 10)
    top = _top_amplitudes(ψ, k)
    println(io, "  Top amplitudes:")
    for (label, amp) in top
        prob = round(abs2(amp), digits=6)
        println(io, "    |$label⟩  amp=$(_fmt(amp))  prob=$prob")
    end
end

function _show_text_nq_mixed(io, ρ, n)
    p = _purity(ρ)
    S = _von_neumann_entropy(ρ)
    println(io, "$n-qubit mixed state")
    println(io, "  Purity: $(_fmt(p))")
    println(io, "  Entropy: $(_fmt(S)) bits")
    k = min(2^n, 10)
    top = _top_probabilities(ρ, k)
    println(io, "  Top diagonal entries:")
    for (label, prob) in top
        println(io, "    |$label⟩  prob=$(_fmt(prob))")
    end
end

function _show_text_large(io, ψ, ρ, n)
    println(io, "$n-qubit state ($(typeof(ρ isa Nothing ? ψ : ρ) |> nameof))")
    println(io, "  Hilbert space dimension: $(2^n)")
    if !isnothing(ρ)
        println(io, "  Purity: $(_fmt(_purity(ρ)))")
        println(io, "  Entropy: $(_fmt(_von_neumann_entropy(ρ))) bits")
    end
    k = 8
    if !isnothing(ψ) && ψ isa Ket
        top = _top_amplitudes(ψ, k)
        println(io, "  Top-$k amplitudes:")
        for (label, amp) in top
            println(io, "    |$label⟩  amp=$(_fmt(amp))  prob=$(_fmt(abs2(amp)))")
        end
    elseif !isnothing(ρ)
        top = _top_probabilities(ρ, k)
        println(io, "  Top-$k probabilities:")
        for (label, prob) in top
            println(io, "    |$label⟩  prob=$(_fmt(prob))")
        end
    end
end

# --- text/html for QuantumOptics kets and operators ---

function stateshow(io, ::MIME"text/html", state::Ket, stateref)
    _is_qubit_state(state) || return invoke(stateshow, Tuple{Any, MIME"text/html", Any, Any}, io, MIME"text/html"(), state, stateref)
    n = _nqubits_qo(state)
    ρ = _to_dm(state)
    if n == 1
        _show_html_1q(io, ρ)
    elseif n == 2
        _show_html_2q(io, ρ)
    elseif n <= _DENSE_VIS_CUTOFF
        _show_html_nq(io, state, ρ, n)
    else
        _show_html_large(io, state, ρ, n)
    end
end

function stateshow(io, ::MIME"text/html", state::Operator, stateref)
    _is_qubit_state(state) || return invoke(stateshow, Tuple{Any, MIME"text/html", Any, Any}, io, MIME"text/html"(), state, stateref)
    n = _nqubits_qo(state)
    if n == 1
        _show_html_1q(io, state)
    elseif n == 2
        _show_html_2q(io, state)
    elseif n <= _DENSE_VIS_CUTOFF
        _show_html_nq(io, nothing, state, n)
    else
        _show_html_large(io, nothing, state, n)
    end
end

function stateshow(io, ::MIME"text/html", state::QuantumClifford.MixedDestabilizer, stateref)
    nq = QuantumClifford.nqubits(state)
    stab = QuantumClifford.stabilizerview(state)
    print(io, """
    <div class="quantumsavory_show quantumsavory_stateshow">
    <strong>Stabilizer state</strong> &mdash; $nq qubits<br>
    <table style="border-collapse:collapse; margin-top:4px; font-family:monospace;">
    <tr><th style="padding:2px 8px; border-bottom:1px solid #888;">Generator</th></tr>
    """)
    for s in _clifford_stabilizer_strings(state)
        escaped = replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;")
        print(io, "<tr><td style=\"padding:2px 8px;\">", escaped, "</td></tr>\n")
    end
    print(io, "</table></div>\n")
end

function _show_html_1q(io, ρ)
    rx, ry, rz = _bloch_vector(ρ)
    ex, ey, ez = _pauli_expectations_1q(ρ)
    p = _purity(ρ)
    S = _von_neumann_entropy(ρ)
    m = _dm_matrix(ρ)
    print(io, """
    <div class="quantumsavory_show quantumsavory_stateshow">
    <strong>Single-qubit state</strong><br>
    <table style="border-collapse:collapse; margin:4px 0;">
    <tr><td style="padding:2px 8px;">Bloch vector</td><td style="padding:2px 8px; font-family:monospace;">($(_fmt(rx)), $(_fmt(ry)), $(_fmt(rz)))</td></tr>
    <tr><td style="padding:2px 8px;">Purity</td><td style="padding:2px 8px;">$(_fmt(p))</td></tr>
    <tr><td style="padding:2px 8px;">Entropy</td><td style="padding:2px 8px;">$(_fmt(S)) bits</td></tr>
    </table>
    <table style="border-collapse:collapse; margin:4px 0;">
    <tr><th style="padding:2px 8px; border-bottom:1px solid #888;">&lang;X&rang;</th><th style="padding:2px 8px; border-bottom:1px solid #888;">&lang;Y&rang;</th><th style="padding:2px 8px; border-bottom:1px solid #888;">&lang;Z&rang;</th></tr>
    <tr><td style="padding:2px 8px; text-align:center;">$(_fmt(ex))</td><td style="padding:2px 8px; text-align:center;">$(_fmt(ey))</td><td style="padding:2px 8px; text-align:center;">$(_fmt(ez))</td></tr>
    </table>
    <strong>Density matrix</strong>
    <table style="border-collapse:collapse; margin:4px 0; font-family:monospace;">
    <tr><th></th><th style="padding:2px 6px;">|0⟩</th><th style="padding:2px 6px;">|1⟩</th></tr>
    <tr><td style="padding:2px 6px;">⟨0|</td><td style="padding:2px 6px; background:rgba(0,100,200,$(_cell_opacity(m[1,1])));">$(_fmt(m[1,1]))</td><td style="padding:2px 6px; background:rgba(0,100,200,$(_cell_opacity(m[1,2])));">$(_fmt(m[1,2]))</td></tr>
    <tr><td style="padding:2px 6px;">⟨1|</td><td style="padding:2px 6px; background:rgba(0,100,200,$(_cell_opacity(m[2,1])));">$(_fmt(m[2,1]))</td><td style="padding:2px 6px; background:rgba(0,100,200,$(_cell_opacity(m[2,2])));">$(_fmt(m[2,2]))</td></tr>
    </table>
    </div>
    """)
end

_cell_opacity(z) = round(clamp(abs(z), 0, 1) * 0.3, digits=3)

function _show_html_2q(io, ρ)
    p = _purity(ρ)
    S = _von_neumann_entropy(ρ)
    m = _dm_matrix(ρ)
    labels = _basis_labels(2)
    print(io, """
    <div class="quantumsavory_show quantumsavory_stateshow">
    <strong>Two-qubit state</strong><br>
    <table style="border-collapse:collapse; margin:4px 0;">
    <tr><td style="padding:2px 8px;">Purity</td><td style="padding:2px 8px;">$(_fmt(p))</td></tr>
    <tr><td style="padding:2px 8px;">Entropy</td><td style="padding:2px 8px;">$(_fmt(S)) bits</td></tr>
    </table>
    <strong>Density matrix</strong>
    <table style="border-collapse:collapse; margin:4px 0; font-family:monospace;">
    <tr><th></th>
    """)
    for l in labels
        print(io, "<th style=\"padding:2px 6px;\">|$l⟩</th>")
    end
    print(io, "</tr>\n")
    for (i, li) in enumerate(labels)
        print(io, "<tr><td style=\"padding:2px 6px;\">⟨$li|</td>")
        for j in 1:4
            print(io, "<td style=\"padding:2px 6px; text-align:right; background:rgba(0,100,200,$(_cell_opacity(m[i,j])));\">$(_fmt(m[i,j]))</td>")
        end
        print(io, "</tr>\n")
    end
    print(io, "</table>\n")
    for q in 1:2
        ρ_red = _reduced_dm(ρ, q)
        bx, by, bz = _bloch_vector(ρ_red)
        rp = _purity(ρ_red)
        print(io, "<div style=\"margin:4px 0;\"><strong>Qubit $q</strong> &mdash; ⟨X⟩=$(_fmt(bx)) ⟨Y⟩=$(_fmt(by)) ⟨Z⟩=$(_fmt(bz)) purity=$(_fmt(rp))</div>\n")
    end
    print(io, "</div>\n")
end

function _show_html_nq(io, ψ, ρ, n)
    p = _purity(ρ)
    S = _von_neumann_entropy(ρ)
    k = min(2^n, 16)
    print(io, """
    <div class="quantumsavory_show quantumsavory_stateshow">
    <strong>$n-qubit state</strong><br>
    <table style="border-collapse:collapse; margin:4px 0;">
    <tr><td style="padding:2px 8px;">Purity</td><td style="padding:2px 8px;">$(_fmt(p))</td></tr>
    <tr><td style="padding:2px 8px;">Entropy</td><td style="padding:2px 8px;">$(_fmt(S)) bits</td></tr>
    </table>
    """)
    if !isnothing(ψ) && ψ isa Ket
        top = _top_amplitudes(ψ, k)
        print(io, """
        <strong>Amplitudes</strong> (top $k)
        <table style="border-collapse:collapse; margin:4px 0; font-family:monospace;">
        <tr><th style="padding:2px 8px; border-bottom:1px solid #888;">Basis</th><th style="padding:2px 8px; border-bottom:1px solid #888;">Amplitude</th><th style="padding:2px 8px; border-bottom:1px solid #888;">Probability</th></tr>
        """)
        for (label, amp) in top
            prob = round(abs2(amp), digits=6)
            print(io, "<tr><td style=\"padding:2px 8px;\">|$label⟩</td><td style=\"padding:2px 8px;\">$(_fmt(amp))</td><td style=\"padding:2px 8px;\">$prob</td></tr>\n")
        end
    else
        top = _top_probabilities(ρ, k)
        print(io, """
        <strong>Diagonal entries</strong> (top $k)
        <table style="border-collapse:collapse; margin:4px 0; font-family:monospace;">
        <tr><th style="padding:2px 8px; border-bottom:1px solid #888;">Basis</th><th style="padding:2px 8px; border-bottom:1px solid #888;">Probability</th></tr>
        """)
        for (label, prob) in top
            print(io, "<tr><td style=\"padding:2px 8px;\">|$label⟩</td><td style=\"padding:2px 8px;\">$(_fmt(prob))</td></tr>\n")
        end
    end
    print(io, "</table></div>\n")
end

function _show_html_large(io, ψ, ρ, n)
    k = 8
    actual_state = isnothing(ρ) ? ψ : ρ
    print(io, """
    <div class="quantumsavory_show quantumsavory_stateshow">
    <strong>$n-qubit state</strong> ($(nameof(typeof(actual_state))))<br>
    <table style="border-collapse:collapse; margin:4px 0;">
    <tr><td style="padding:2px 8px;">Hilbert space dim</td><td style="padding:2px 8px;">$(2^n)</td></tr>
    """)
    if !isnothing(ρ)
        print(io, "<tr><td style=\"padding:2px 8px;\">Purity</td><td style=\"padding:2px 8px;\">$(_fmt(_purity(ρ)))</td></tr>\n")
        print(io, "<tr><td style=\"padding:2px 8px;\">Entropy</td><td style=\"padding:2px 8px;\">$(_fmt(_von_neumann_entropy(ρ))) bits</td></tr>\n")
    end
    print(io, "</table>\n")
    if !isnothing(ψ) && ψ isa Ket
        top = _top_amplitudes(ψ, k)
        print(io, "<strong>Top-$k amplitudes</strong>\n<table style=\"border-collapse:collapse; margin:4px 0; font-family:monospace;\">\n")
        print(io, "<tr><th style=\"padding:2px 8px; border-bottom:1px solid #888;\">Basis</th><th style=\"padding:2px 8px; border-bottom:1px solid #888;\">Amplitude</th><th style=\"padding:2px 8px; border-bottom:1px solid #888;\">Prob</th></tr>\n")
        for (label, amp) in top
            print(io, "<tr><td style=\"padding:2px 8px;\">|$label⟩</td><td style=\"padding:2px 8px;\">$(_fmt(amp))</td><td style=\"padding:2px 8px;\">$(_fmt(abs2(amp)))</td></tr>\n")
        end
        print(io, "</table>\n")
    elseif !isnothing(ρ)
        top = _top_probabilities(ρ, k)
        print(io, "<strong>Top-$k probabilities</strong>\n<table style=\"border-collapse:collapse; margin:4px 0; font-family:monospace;\">\n")
        print(io, "<tr><th style=\"padding:2px 8px; border-bottom:1px solid #888;\">Basis</th><th style=\"padding:2px 8px; border-bottom:1px solid #888;\">Prob</th></tr>\n")
        for (label, prob) in top
            print(io, "<tr><td style=\"padding:2px 8px;\">|$label⟩</td><td style=\"padding:2px 8px;\">$(_fmt(prob))</td></tr>\n")
        end
        print(io, "</table>\n")
    end
    print(io, "</div>\n")
end

