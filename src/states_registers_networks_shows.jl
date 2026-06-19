using LinearAlgebra
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
        stateshow(io, MIME"text/plain"(), quantumstate(s), s)
    end
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
function stateshow(io, ::MIME"text/plain", state, stateref)
    print(io, "\n\n")
    show(io, MIME"text/plain"(), state)
end

_html_escape_text(text) = replace(text, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;")

function stateshow(io, ::MIME"text/html", state, stateref)
    text = sprint(show, MIME"text/plain"(), state; context=io)
    type_name = _html_escape_text(string(typeof(state)))
    print(io, """
    <div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_unknown">
    <p>
    state of type <code class="quantumsavory_typename quantumsavory_numericalstate_typename">$type_name</code>
    does not support rich visualization in HTML
    </p>
    <pre class="quantumsavory_numericalstate_plaintext">$(_html_escape_text(text))</pre>
    </div>
    """)
end

# ── Rich display helpers and stateshow dispatch (Issue #401) ──────────────────

const _QS_DISPLAY_MAX_DENSE_DIM = 32
const _QS_DISPLAY_TOP_K = 8

function _basis_dimensions(state::QuantumOpticsBase.StateVector)
    return Int.(state.basis.shape)
end
function _basis_dimensions(state::QuantumOpticsBase.AbstractOperator)
    return Int.(state.basis_l.shape)
end

function _dense_density_matrix(state::QuantumOpticsBase.Ket)
    v = state.data
    return v * v'
end
function _dense_density_matrix(state::QuantumOpticsBase.AbstractOperator)
    return Matrix(state.data)
end

function _purity(rho::Matrix)
    return real(tr(rho * rho))
end

function _von_neumann_entropy(rho::Matrix)
    evals = real.(eigvals(Hermitian((rho + rho') / 2)))
    s = 0.0
    for λ in evals
        λ > 1e-14 && (s -= λ * log2(λ))
    end
    return s
end

function _pauli_expectations_from_density_matrix(rho::Matrix{<:Number})
    sx = real(rho[1,2] + rho[2,1])
    sy = real(1im * (rho[2,1] - rho[1,2]))
    sz = real(rho[1,1] - rho[2,2])
    return [("X", sx), ("Y", sy), ("Z", sz)]
end

function _format_real(x::Real; digits::Int=4)
    v = round(x; digits)
    v == round(Int, v) ? string(round(Int, v)) : string(v)
end

function _format_complex(z::Number; digits::Int=3)
    re  = round(real(z); digits)
    im_ = round(imag(z); digits)
    iszero(im_) && return _format_real(re; digits)
    iszero(re)  && return "$(_format_real(im_; digits))im"
    sign = im_ >= 0 ? "+" : "-"
    return "$(_format_real(re; digits))$(sign)$(_format_real(abs(im_); digits))im"
end

function _basis_label(idx::Int, dims::Vector{Int})
    parts = String[]
    remaining = idx
    for d in reverse(dims)
        push!(parts, string(remaining % d))
        remaining = remaining ÷ d
    end
    return "|" * join(reverse(parts), ",") * "⟩"
end

function _top_probability_rows(
        state::Union{<:QuantumOpticsBase.Ket, <:QuantumOpticsBase.AbstractOperator};
        topk::Int = _QS_DISPLAY_TOP_K)
    dims  = _basis_dimensions(state)
    N     = prod(dims)
    N > _QS_DISPLAY_MAX_DENSE_DIM * 4 && return Tuple{String,Float64}[]
    rho   = _dense_density_matrix(state)
    probs = real.(diag(rho))
    nshow = min(topk, N)
    idx   = partialsortperm(probs, 1:nshow; rev=true)
    rows  = Tuple{String,Float64}[]
    for i in idx
        probs[i] < 1e-12 && continue
        push!(rows, (_basis_label(i - 1, dims), probs[i]))
    end
    return rows
end

function _stateref_summary_lines(
        state::Union{<:QuantumOpticsBase.Ket, <:QuantumOpticsBase.AbstractOperator},
        stateref; topk::Int = 6)
    lines = String[]
    dims  = _basis_dimensions(state)
    N     = prod(dims)
    nsub  = length(dims)
    push!(lines, "Backend: QuantumOpticsBase")
    push!(lines, "Subsystems: $nsub   dims: $(join(string.(dims), "×"))")
    if N <= _QS_DISPLAY_MAX_DENSE_DIM
        rho = _dense_density_matrix(state)
        push!(lines, "Purity:   $(_format_real(_purity(rho)))")
        push!(lines, "Entropy:  $(_format_real(_von_neumann_entropy(rho))) bits")
        if nsub == 1 && dims == [2]
            pq = _pauli_expectations_from_density_matrix(rho)
            push!(lines, "Bloch:  ⟨X⟩=$(_format_real(pq[1][2]))  ⟨Y⟩=$(_format_real(pq[2][2]))  ⟨Z⟩=$(_format_real(pq[3][2]))")
        end
    end
    rows = _top_probability_rows(state; topk)
    if !isempty(rows)
        push!(lines, "Top probabilities:")
        for (lbl, p) in rows
            push!(lines, "  $lbl  $(round(p*100; digits=1))%")
        end
    elseif N > _QS_DISPLAY_MAX_DENSE_DIM
        push!(lines, "(dim=$N — dense display suppressed)")
    end
    return lines
end

# ── plain-text stateshow ──────────────────────────────────────────────────────


function stateshow(
        io::IO, ::MIME"text/plain",
        state::Union{<:QuantumOpticsBase.Ket, <:QuantumOpticsBase.AbstractOperator},
        stateref)
    dims = _basis_dimensions(state)
    N    = prod(dims)
    nsub = length(dims)
    println(io)
    println(io, "  QuantumOpticsBase state — $nsub subsystem$(nsub==1 ? "" : "s"), dim=$N")
    if N <= _QS_DISPLAY_MAX_DENSE_DIM
        rho = _dense_density_matrix(state)
        println(io, "  Purity:          $(_format_real(_purity(rho)))")
        println(io, "  Entropy (bits):  $(_format_real(_von_neumann_entropy(rho)))")
        if nsub == 1 && dims == [2]
            pq = _pauli_expectations_from_density_matrix(rho)
            println(io, "  ⟨X⟩=$(_format_real(pq[1][2]))   ⟨Y⟩=$(_format_real(pq[2][2]))   ⟨Z⟩=$(_format_real(pq[3][2]))")
            println(io, "  Bloch |r|=$(_format_real(sqrt(sum(x->x[2]^2, pq))))")
        elseif nsub == 2 && prod(dims) <= 4
            d1, d2 = dims
            rho1 = Matrix{ComplexF64}(undef, d1, d1)
            for i in 1:d1, j in 1:d1
                rho1[i,j] = sum(rho[(i-1)*d2+m, (j-1)*d2+m] for m in 1:d2)
            end
            rho2 = Matrix{ComplexF64}(undef, d2, d2)
            for i in 1:d2, j in 1:d2
                rho2[i,j] = sum(rho[(m-1)*d2+i, (m-1)*d2+j] for m in 1:d1)
            end
            if size(rho1) == (2,2)
                pq1 = _pauli_expectations_from_density_matrix(rho1)
                println(io, "  Qubit 1 — ⟨X⟩=$(_format_real(pq1[1][2]))  ⟨Y⟩=$(_format_real(pq1[2][2]))  ⟨Z⟩=$(_format_real(pq1[3][2]))")
            end
            if size(rho2) == (2,2)
                pq2 = _pauli_expectations_from_density_matrix(rho2)
                println(io, "  Qubit 2 — ⟨X⟩=$(_format_real(pq2[1][2]))  ⟨Y⟩=$(_format_real(pq2[2][2]))  ⟨Z⟩=$(_format_real(pq2[3][2]))")
            end
        end
        if N <= 4
            println(io, "  Density matrix:")
            for i in 1:N
                print(io, "    ")
                for j in 1:N
                    print(io, lpad(_format_complex(rho[i,j]), 16))
                end
                println(io)
            end
        end
    end
    rows = _top_probability_rows(state; topk=_QS_DISPLAY_TOP_K)
    if !isempty(rows)
        println(io, "  Top basis probabilities:")
        for (lbl, p) in rows
            bar = "█" ^ round(Int, p * 20)
            println(io, "    $lbl  $(lpad(string(round(p*100; digits=1))*"%", 6))  $bar")
        end
    elseif N > _QS_DISPLAY_MAX_DENSE_DIM
        println(io, "  (dim=$N — dense display suppressed)")
    end
end

function stateshow(io::IO, ::MIME"text/plain", state::QuantumClifford.MixedDestabilizer, stateref)
    stab = QuantumClifford.stabilizerview(state)
    nq   = QuantumClifford.nqubits(stab)
    println(io)
    println(io, "  QuantumClifford stabilizer state — $nq qubits")
    println(io, "  Stabilizer generators:")
    for i in 1:length(stab)
        println(io, "    ", stab[i])
    end
end

# ── HTML stateshow ────────────────────────────────────────────────────────────

function stateshow(
        io::IO, m::MIME"text/html",
        state::Union{<:QuantumOpticsBase.Ket, <:QuantumOpticsBase.AbstractOperator},
        stateref)
    dims = _basis_dimensions(state)
    N    = prod(dims)
    nsub = length(dims)
    print(io, """<div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_qob" style="font-family:monospace;padding:6px 0">""")
    print(io, "<b>QuantumOpticsBase</b> — $nsub subsystem$(nsub==1 ? "" : "s"), dim=$N<br>")
    if N <= _QS_DISPLAY_MAX_DENSE_DIM
        rho = _dense_density_matrix(state)
        p   = _purity(rho)
        s_  = _von_neumann_entropy(rho)
        print(io, "<table style='border-collapse:collapse;margin:4px 0;font-size:0.92em'>")
        print(io, "<tr><td style='padding-right:1em'>Purity</td><td><b>$(_format_real(p))</b></td></tr>")
        print(io, "<tr><td>Entropy (bits)</td><td><b>$(_format_real(s_))</b></td></tr>")
        if nsub == 1 && dims == [2]
            pq = _pauli_expectations_from_density_matrix(rho)
            print(io, "<tr><td>⟨X⟩</td><td>$(_format_real(pq[1][2]))</td></tr>")
            print(io, "<tr><td>⟨Y⟩</td><td>$(_format_real(pq[2][2]))</td></tr>")
            print(io, "<tr><td>⟨Z⟩</td><td>$(_format_real(pq[3][2]))</td></tr>")
        end
        print(io, "</table>")
        if N <= 4
            print(io, "<details><summary style='cursor:pointer'>Density matrix</summary><pre style='margin:4px 0'>")
            for i in 1:N
                for j in 1:N
                    print(io, lpad(_format_complex(rho[i,j]), 16))
                end
                println(io)
            end
            print(io, "</pre></details>")
        end
    end
    rows = _top_probability_rows(state; topk=_QS_DISPLAY_TOP_K)
    if !isempty(rows)
        print(io, "<details open><summary style='cursor:pointer'>Top basis probabilities</summary>")
        print(io, "<table style='border-collapse:collapse;font-size:0.9em'><tr><th style='padding-right:8px'>State</th><th>Prob</th><th></th></tr>")
        for (lbl, prob) in rows
            wpx = round(Int, prob * 120)
            print(io, "<tr><td style='padding-right:8px'>$lbl</td><td>$(round(prob*100;digits=1))%</td><td><div style='background:#4472C4;width:$(wpx)px;height:10px;display:inline-block'></div></td></tr>")
        end
        print(io, "</table></details>")
    elseif N > _QS_DISPLAY_MAX_DENSE_DIM
        print(io, "<i style='color:#888'>(dim=$N — dense display suppressed)</i>")
    end
    print(io, "</div>")
end

function stateshow(io::IO, m::MIME"text/html", state::QuantumClifford.MixedDestabilizer, stateref)
    stab = QuantumClifford.stabilizerview(state)
    nq   = QuantumClifford.nqubits(stab)
    print(io, """<div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_clifford" style="font-family:monospace;padding:6px 0">""")
    print(io, "<b>QuantumClifford stabilizer state</b> — $nq qubits<br>")
    print(io, "<details open><summary style='cursor:pointer'>Stabilizer generators</summary><pre style='margin:4px 0'>")
    for i in 1:length(stab)
        println(io, "  ", stab[i])
    end
    print(io, "</pre></details></div>")
end