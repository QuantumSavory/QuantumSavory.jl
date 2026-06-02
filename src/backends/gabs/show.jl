"""Indices of the two quadratures belonging to `mode` in `basis`."""
function _gabs_mode_quadrature_indices(basis, mode::Int)
    n = Gabs.nmodes(basis)
    @assert 1 <= mode <= n
    if basis isa Gabs.QuadBlockBasis
        return mode, mode + n
    elseif basis isa Gabs.QuadPairBasis
        return 2 * mode - 1, 2 * mode
    else
        return mode, mode + n
    end
end

"""Bosonic mode index for quadrature component `idx` in `basis`."""
function _gabs_quadrature_mode_index(basis, idx::Int)
    n = Gabs.nmodes(basis)
    if basis isa Gabs.QuadBlockBasis
        return idx <= n ? idx : idx - n
    elseif basis isa Gabs.QuadPairBasis
        return (idx + 1) ÷ 2
    else
        return idx <= n ? idx : idx - n
    end
end

function _gabs_mode_marginal(state::Gabs.GaussianState, mode::Int)
    ix, ip = _gabs_mode_quadrature_indices(state.basis, mode)
    μ = [state.mean[ix], state.mean[ip]]
    V = state.covar[[ix, ip], [ix, ip]]
    return μ, V
end

function _gabs_covariance_summary(covar::AbstractMatrix)
    n = size(covar, 1)
    diag_part = [covar[i, i] for i in 1:n]
    max_offdiag = 0.0
    for i in 1:n, j in 1:n
        i == j && continue
        max_offdiag = max(max_offdiag, abs(covar[i, j]))
    end
    return diag_part, max_offdiag
end

function _gabs_purity_or_mixedness(state::Gabs.GaussianState)
    try
        return "Purity: $(round(Gabs.purity(state); digits=4))"
    catch
        diag_part, _ = _gabs_covariance_summary(state.covar)
        return "Tr(cov): $(round(sum(diag_part); digits=4))"
    end
end

function _gabs_print_mode_marginals_plain(io::IO, state::Gabs.GaussianState)
    n = nsubsystems(state)
    n == 1 && return
    print(io, "\n  Per-mode marginals:")
    for mode in 1:n
        μ, V = _gabs_mode_marginal(state, mode)
        print(io, "\n    mode $mode: ⟨q⟩=$(round(μ[1]; digits=4)), ⟨p⟩=$(round(μ[2]; digits=4)), ",
            "Var(q)=$(round(V[1,1]; digits=4)), Var(p)=$(round(V[2,2]; digits=4)), ",
            "Cov(q,p)=$(round(V[1,2]; digits=4))")
    end
end

function _gabs_html_cov_cell(val, i, j, basis)
    mode_i = _gabs_quadrature_mode_index(basis, i)
    mode_j = _gabs_quadrature_mode_index(basis, j)
    same_mode = mode_i == mode_j
    bg = i == j ? "background-color: #f0f0f0;" :
        (same_mode ? "background-color: #f5f5ff;" :
         (abs(val) > 1e-5 ? "background-color: #fff5f5;" : ""))
    fw = i == j ? "font-weight: bold;" : (same_mode ? "" : "font-style: italic;")
    return "<td style=\"border: 1px solid #ccc; padding: 2px 6px; $bg $fw\">$(round(val; digits=4))</td>"
end

function QuantumSavory.stateshow(io::IO, ::MIME"text/plain", state::Gabs.GaussianState, stateref)
    n = nsubsystems(state)
    print(io, "\n  Gaussian state of $n mode", n == 1 ? "" : "s")
    print(io, "\n  Basis: ", typeof(state.basis))
    print(io, "\n  First moments: ", round.(state.mean; digits=4))
    diag_part, max_offdiag = _gabs_covariance_summary(state.covar)
    print(io, "\n  Covariance matrix: ", size(state.covar, 1), "×", size(state.covar, 2),
        " (diag: ", join(round.(diag_part; digits=4), ", "), "; max |off-diag|: ",
        round(max_offdiag; digits=4), ")")
    print(io, "\n  ", _gabs_purity_or_mixedness(state))
    _gabs_print_mode_marginals_plain(io, state)
end

function QuantumSavory.stateshow(io::IO, ::MIME"text/html", state::Gabs.GaussianState, stateref)
    n = nsubsystems(state)
    print(io, """<div class="quantumsavory_show quantumsavory_numericalstate">""")
    print(io, "<div><strong>GaussianState</strong> of $n mode", n == 1 ? "" : "s",
        " (Basis: <code>$(typeof(state.basis))</code>; ", _gabs_purity_or_mixedness(state), ")</div>")

    print(io, "<div><strong>First moments</strong>:</div>")
    print(io, "<table><tr>")
    for v in state.mean
        print(io, "<td style=\"padding: 2px 6px;\">$(round(v; digits=4))</td>")
    end
    print(io, "</tr></table>")

    print(io, "<div><strong>Covariance matrix</strong>:</div>")
    print(io, "<table style=\"border-collapse: collapse;\">")
    for i in 1:size(state.covar, 1)
        print(io, "<tr>")
        for j in 1:size(state.covar, 2)
            print(io, _gabs_html_cov_cell(state.covar[i, j], i, j, state.basis))
        end
        print(io, "</tr>")
    end
    print(io, "</table>")

    if n > 1
        print(io, "<div><strong>Per-mode marginals</strong>:</div>")
        for mode in 1:n
            μ, V = _gabs_mode_marginal(state, mode)
            print(io, "<div>Mode $mode</div><table style=\"border-collapse: collapse; margin-bottom: 0.5em;\">")
            print(io, "<tr><th></th><th>mean</th><th>var(q)</th><th>var(p)</th><th>cov(q,p)</th></tr>")
            print(io, "<tr><td></td><td>$(round.(μ; digits=4))</td><td>$(round(V[1,1]; digits=4))</td>",
                "<td>$(round(V[2,2]; digits=4))</td><td>$(round(V[1,2]; digits=4))</td></tr>")
            print(io, "</table>")
        end
    end
    print(io, "</div>")
end
