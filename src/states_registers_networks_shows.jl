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
        stateshowtext(io, s.state[], s)
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
function stateshow(io, ::MIME"text/html", state, stateref)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_unknown">
    state of type <pre class="quantumsavory_typename quantumsavory_numericalstate_typename">$(typeof(state))</pre> does not support rich visualization in HTML
    </div>
    """)
end

"""Plain-text companion to `stateshow` for `StateRef` summaries."""
function stateshowtext(io::IO, state, stateref)
    print(io, "\n  State summary:")
    print(io, "\n    type: $(typeof(state))")
end

const _QS_DISPLAY_MAX_DENSE_DIM = 32
const _QS_DISPLAY_FULL_MATRIX_DIM = 4
const _QS_DISPLAY_TOPK = 6

_html_escape(x) = replace(string(x), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

function _format_real(x; digits=5)
    y = real(x)
    abs(y) < 10.0^(-digits-2) && (y = zero(y))
    return Printf.@sprintf("%.*g", digits, y)
end

function _format_complex(z; digits=5)
    r = real(z)
    i = imag(z)
    abs(r) < 10.0^(-digits-2) && (r = zero(r))
    abs(i) < 10.0^(-digits-2) && (i = zero(i))
    iszero(i) && return _format_real(r; digits)
    iszero(r) && return "$(Printf.@sprintf("%.*g", digits, i))im"
    sign = i < 0 ? "-" : "+"
    return "$(Printf.@sprintf("%.*g", digits, r)) $(sign) $(Printf.@sprintf("%.*g", digits, abs(i)))im"
end

function _basis_dimensions(state)::Vector{Int}
    b = basis(state)
    hasproperty(b, :shape) && return Int.(collect(getproperty(b, :shape)))
    return [length(b)]
end

function _density_operator(state::Ket)
    dm(state)
end

function _density_operator(state::Operator)
    state
end

function _dense_density_matrix(state::Union{<:Ket,<:Operator})
    rho = _density_operator(state)
    Matrix(rho.data)
end

function _state_probabilities(state::Ket)::Vector{Float64}
    Float64.(real.(abs2.(state.data)))
end

function _state_probabilities(state::Operator)::Vector{Float64}
    Float64.(real.(LinearAlgebra.diag(state.data)))
end

function _entropy_from_density_matrix(mat)
    vals = LinearAlgebra.eigvals(mat)
    entropy = 0.0
    for val in vals
        p = real(val)
        p > 1e-12 || continue
        entropy -= p * log(p)
    end
    entropy
end

function _purity_from_density_matrix(mat)
    real(LinearAlgebra.tr(mat * mat))
end

function _basis_label(idx::Integer, dims::AbstractVector{<:Integer})::String
    digits = Vector{Int}(undef, length(dims))
    x = idx - 1
    for i in length(dims):-1:1
        digits[i] = x % dims[i]
        x ÷= dims[i]
    end
    return all(==(2), dims) ? "|" * join(digits) * ">" : "|" * join(digits, ",") * ">"
end

function _top_probability_rows(state::Union{<:Ket,<:Operator}; topk=_QS_DISPLAY_TOPK)
    dims = _basis_dimensions(state)
    probs = _state_probabilities(state)
    order = partialsortperm(probs, 1:min(topk, length(probs)); rev=true)
    rows = Tuple{String,Float64}[]
    for idx in order
        probs[idx] > 1e-12 || continue
        push!(rows, (_basis_label(idx, dims), probs[idx]))
    end
    rows
end

function _pauli_expectations_from_density_matrix(mat)::Vector{Tuple{String,Float64}}
    sx = ComplexF64[0 1; 1 0]
    sy = ComplexF64[0 -im; im 0]
    sz = ComplexF64[1 0; 0 -1]
    Tuple{String,Float64}[
        ("X", Float64(real(LinearAlgebra.tr(sx * mat)))),
        ("Y", Float64(real(LinearAlgebra.tr(sy * mat)))),
        ("Z", Float64(real(LinearAlgebra.tr(sz * mat)))),
    ]
end

function _reduced_density_matrix(state::Union{<:Ket,<:Operator}, keep::Integer)
    n = nsubsystems(state)
    rho = _density_operator(state)
    n == 1 && return Matrix(rho.data)
    traced = [i for i in 1:n if i != keep]
    Matrix(ptrace(rho, traced).data)
end

function _pauli_correlations_from_density_matrix(mat)
    paulis = [
        ("X", ComplexF64[0 1; 1 0]),
        ("Y", ComplexF64[0 -im; im 0]),
        ("Z", ComplexF64[1 0; 0 -1]),
    ]
    rows = Tuple{String,Float64}[]
    for (aname, aop) in paulis, (bname, bop) in paulis
        push!(rows, (aname * bname, real(LinearAlgebra.tr(LinearAlgebra.kron(aop, bop) * mat))))
    end
    rows
end

function _format_expectation_rows(rows::Vector{Tuple{String,Float64}})::String
    join(["<$(name)>=$(_format_real(val))" for (name, val) in rows], ", ")
end

function _density_matrix_rows(state::Union{<:Ket,<:Operator}; maxdim=_QS_DISPLAY_FULL_MATRIX_DIM)
    dims = _basis_dimensions(state)
    mat = _dense_density_matrix(state)
    size(mat, 1) <= maxdim || return String[]
    labels = [_basis_label(i, dims) for i in 1:size(mat, 1)]
    rows = String[]
    push!(rows, "density matrix:")
    for i in 1:size(mat, 1)
        entries = [_format_complex(mat[i, j]) for j in 1:size(mat, 2)]
        push!(rows, "  $(labels[i])  [" * join(entries, "  ") * "]")
    end
    rows
end

function _stateref_summary_lines(state::Union{<:Ket,<:Operator}, stateref; topk=_QS_DISPLAY_TOPK)
    dims = _basis_dimensions(state)
    n = nsubsystems(state)
    dim = prod(dims)
    mat = dim <= _QS_DISPLAY_MAX_DENSE_DIM ? _dense_density_matrix(state) : nothing
    lines = String[]
    push!(lines, "backend: QuantumOpticsBase $(nameof(typeof(state)))")
    push!(lines, "subsystems: $(n); basis dimensions: $(join(dims, " x "))")
    if isnothing(mat)
        push!(lines, "purity and entropy omitted: dimension $(dim) exceeds $(_QS_DISPLAY_MAX_DENSE_DIM)")
    else
        push!(lines, "purity: $(_format_real(_purity_from_density_matrix(mat))); entropy: $(_format_real(_entropy_from_density_matrix(mat))) nats")
    end

    if !isnothing(mat) && all(==(2), dims) && n == 1 && size(mat) == (2, 2)
        paulis = _pauli_expectations_from_density_matrix(mat)
        push!(lines, "Bloch vector / Pauli expectations: $(_format_expectation_rows(paulis))")
    elseif !isnothing(mat) && all(==(2), dims) && n == 2 && size(mat) == (4, 4)
        for i in 1:2
            paulis = _pauli_expectations_from_density_matrix(_reduced_density_matrix(state, i))
            push!(lines, "reduced qubit $(i): $(_format_expectation_rows(paulis))")
        end
        push!(lines, "Pauli correlations: $(_format_expectation_rows(_pauli_correlations_from_density_matrix(mat)))")
    end

    if !isnothing(mat)
        append!(lines, _density_matrix_rows(state))
    else
        push!(lines, "density matrix omitted: dimension $(dim) exceeds $(_QS_DISPLAY_MAX_DENSE_DIM)")
    end

    probrows = _top_probability_rows(state; topk)
    isempty(probrows) || push!(lines, "top probabilities: " * join(["$(label)=$(_format_real(prob))" for (label, prob) in probrows], ", "))
    lines
end

function _stateref_summary_lines(state::MixedDestabilizer, stateref; topk=_QS_DISPLAY_TOPK)
    stab = QuantumClifford.stabilizerview(state)
    rows, cols = size(stab)
    table = split(chomp(sprint(show, MIME"text/plain"(), stab)), '\n')
    shown = first(table, min(length(table), topk))
    lines = [
        "backend: QuantumClifford MixedDestabilizer",
        "qubits: $(QuantumClifford.nqubits(state)); rank: $(LinearAlgebra.rank(state)); stabilizer rows: $(rows); columns: $(cols)",
        "stabilizer view:",
    ]
    append!(lines, ["  " * row for row in shown])
    length(table) > length(shown) && push!(lines, "  ... $(length(table) - length(shown)) more rows")
    lines
end

function stateshowtext(io::IO, state::Union{<:Ket,<:Operator}, stateref)
    print(io, "\n  State summary:")
    for line in _stateref_summary_lines(state, stateref)
        print(io, "\n    ", line)
    end
end

function stateshowtext(io::IO, state::MixedDestabilizer, stateref)
    print(io, "\n  State summary:")
    for line in _stateref_summary_lines(state, stateref)
        print(io, "\n    ", line)
    end
end

function _html_table(io, headers, rows; class="")
    print(io, "<table class=\"$(class)\"><thead><tr>")
    for header in headers
        print(io, "<th>$(_html_escape(header))</th>")
    end
    print(io, "</tr></thead><tbody>")
    for row in rows
        print(io, "<tr>")
        for cell in row
            print(io, "<td>$(_html_escape(cell))</td>")
        end
        print(io, "</tr>")
    end
    print(io, "</tbody></table>")
end

function _html_density_matrix(io, state::Union{<:Ket,<:Operator})
    dims = _basis_dimensions(state)
    mat = _dense_density_matrix(state)
    size(mat, 1) <= _QS_DISPLAY_FULL_MATRIX_DIM || return
    labels = [_basis_label(i, dims) for i in 1:size(mat, 1)]
    rows = [[labels[i]; [_format_complex(mat[i, j]) for j in 1:size(mat, 2)]] for i in 1:size(mat, 1)]
    _html_table(io, ["rho"; labels], rows; class="quantumsavory_density_matrix")
end

function _html_probability_table(io, state::Union{<:Ket,<:Operator})
    rows = [[label, _format_real(prob)] for (label, prob) in _top_probability_rows(state)]
    isempty(rows) || _html_table(io, ["basis state", "probability"], rows; class="quantumsavory_probabilities")
end

function stateshow(io, ::MIME"text/html", state::Union{<:Ket,<:Operator}, stateref)
    dims = _basis_dimensions(state)
    n = nsubsystems(state)
    dim = prod(dims)
    mat = dim <= _QS_DISPLAY_MAX_DENSE_DIM ? _dense_density_matrix(state) : nothing
    metric_rows = [
        ["backend", string(nameof(typeof(state)))],
        ["subsystems", string(n)],
        ["basis dimensions", join(dims, " x ")],
    ]
    if isnothing(mat)
        push!(metric_rows, ["purity", "omitted for dimension $(dim)"])
        push!(metric_rows, ["entropy (nats)", "omitted for dimension $(dim)"])
    else
        push!(metric_rows, ["purity", _format_real(_purity_from_density_matrix(mat))])
        push!(metric_rows, ["entropy (nats)", _format_real(_entropy_from_density_matrix(mat))])
    end
    print(io, """
    <div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_quantumoptics">
    <h4>QuantumOpticsBase state summary</h4>
    """)
    _html_table(io, ["quantity", "value"], metric_rows; class="quantumsavory_state_metrics")

    if !isnothing(mat) && all(==(2), dims) && n == 1 && size(mat) == (2, 2)
        print(io, "<h5>Bloch vector / Pauli expectations</h5>")
        _html_table(io, ["Pauli", "expectation"], [[name, _format_real(val)] for (name, val) in _pauli_expectations_from_density_matrix(mat)]; class="quantumsavory_pauli_expectations")
    elseif !isnothing(mat) && all(==(2), dims) && n == 2 && size(mat) == (4, 4)
        print(io, "<h5>Reduced single-qubit summaries</h5>")
        rows = Vector{Vector{String}}()
        for i in 1:2
            for (name, val) in _pauli_expectations_from_density_matrix(_reduced_density_matrix(state, i))
                push!(rows, ["qubit $(i)", name, _format_real(val)])
            end
        end
        _html_table(io, ["subsystem", "Pauli", "expectation"], rows; class="quantumsavory_reduced_pauli_expectations")
        print(io, "<h5>Pauli correlations</h5>")
        _html_table(io, ["correlation", "expectation"], [[name, _format_real(val)] for (name, val) in _pauli_correlations_from_density_matrix(mat)]; class="quantumsavory_pauli_correlations")
    end

    if isnothing(mat)
        print(io, "<p>Density matrix omitted for dimension $(_html_escape(dim)); showing top basis probabilities instead.</p>")
    else
        _html_density_matrix(io, state)
    end
    _html_probability_table(io, state)
    print(io, "</div>")
end

function stateshow(io, ::MIME"text/html", state::MixedDestabilizer, stateref)
    rows = [[line] for line in _stateref_summary_lines(state, stateref)]
    print(io, """
    <div class="quantumsavory_show quantumsavory_numericalstate quantumsavory_numericalstate_clifford">
    <h4>QuantumClifford stabilizer summary</h4>
    """)
    _html_table(io, ["summary"], rows; class="quantumsavory_clifford_summary")
    print(io, "</div>")
end
