function _gabs_mode_axes(state::Gabs.GaussianState{<:Gabs.QuadPairBasis}, mode::Integer)
    return (2mode - 1, 2mode)
end

function _gabs_mode_axes(state::Gabs.GaussianState{<:Gabs.QuadBlockBasis}, mode::Integer)
    n = Gabs.nmodes(state)
    return (mode, n + mode)
end

function _gabs_quadrature_labels(state::Gabs.GaussianState{<:Gabs.QuadPairBasis})
    return reduce(vcat, (["q$(i)", "p$(i)"] for i in 1:Gabs.nmodes(state)))
end

function _gabs_quadrature_labels(state::Gabs.GaussianState{<:Gabs.QuadBlockBasis})
    n = Gabs.nmodes(state)
    return [("q$(i)" for i in 1:n)..., ("p$(i)" for i in 1:n)...]
end

function _gabs_mode_mean(state::Gabs.GaussianState, mode::Integer)
    axes = _gabs_mode_axes(state, mode)
    return state.mean[[axes...]]
end

function _gabs_mode_covariance(state::Gabs.GaussianState, mode::Integer)
    axes = _gabs_mode_axes(state, mode)
    return state.covar[[axes...], [axes...]]
end

function _gabs_mode_purity(state::Gabs.GaussianState, mode::Integer)
    covar = _gabs_mode_covariance(state, mode)
    return (state.ħ / 2) / sqrt(LinearAlgebra.det(covar))
end

function _gabs_inter_mode_covariance(state::Gabs.GaussianState)
    n = Gabs.nmodes(state)
    n <= 1 && return zero(eltype(state.covar))
    maxcorr = zero(eltype(state.covar))
    for mode_a in 1:n, mode_b in mode_a+1:n
        axes_a = _gabs_mode_axes(state, mode_a)
        axes_b = _gabs_mode_axes(state, mode_b)
        block = @view state.covar[[axes_a...], [axes_b...]]
        maxcorr = max(maxcorr, maximum(abs, block))
    end
    return maxcorr
end

_gabs_basis_name(state::Gabs.GaussianState) = String(nameof(typeof(state.basis)))
_gabs_fmt(x) = sprint(show, round(x; sigdigits = 6))

function stateshow(io, ::MIME"text/plain", state::Gabs.GaussianState, stateref)
    n = Gabs.nmodes(state)
    println(io)
    print(io, "\nGaussian state summary")
    print(io, "\n  Modes: ", n)
    print(io, "\n  Basis: ", _gabs_basis_name(state))
    print(io, "\n  Purity: ", _gabs_fmt(Gabs.purity(state)))
    print(io, "\n  First moments:")
    for mode in 1:n
        mean = _gabs_mode_mean(state, mode)
        print(io, "\n    mode ", mode, ": q=", _gabs_fmt(mean[1]), ", p=", _gabs_fmt(mean[2]))
    end
    print(io, "\n  Covariance by mode:")
    for mode in 1:n
        covar = _gabs_mode_covariance(state, mode)
        print(
            io,
            "\n    mode ", mode,
            ": Var(q)=", _gabs_fmt(covar[1, 1]),
            ", Var(p)=", _gabs_fmt(covar[2, 2]),
            ", Cov(q,p)=", _gabs_fmt(covar[1, 2]),
            ", marginal purity=", _gabs_fmt(_gabs_mode_purity(state, mode)),
        )
    end
    print(io, "\n  Max |inter-mode covariance|: ", _gabs_fmt(_gabs_inter_mode_covariance(state)))
end

function _gabs_html_table(io, headers, rows; class = "")
    print(io, "<table class=\"", class, "\"><thead><tr>")
    for header in headers
        print(io, "<th>", header, "</th>")
    end
    print(io, "</tr></thead><tbody>")
    for row in rows
        print(io, "<tr>")
        for cell in row
            print(io, "<td>", cell, "</td>")
        end
        print(io, "</tr>")
    end
    print(io, "</tbody></table>")
end

function stateshow(io, ::MIME"text/html", state::Gabs.GaussianState, stateref)
    n = Gabs.nmodes(state)
    labels = _gabs_quadrature_labels(state)
    moment_rows = [
        (mode, _gabs_fmt(_gabs_mode_mean(state, mode)[1]), _gabs_fmt(_gabs_mode_mean(state, mode)[2]))
        for mode in 1:n
    ]
    marginal_rows = [
        begin
            covar = _gabs_mode_covariance(state, mode)
            (
                mode,
                _gabs_fmt(covar[1, 1]),
                _gabs_fmt(covar[2, 2]),
                _gabs_fmt(covar[1, 2]),
                _gabs_fmt(_gabs_mode_purity(state, mode)),
            )
        end
        for mode in 1:n
    ]

    print(io, """
    <div class="quantumsavory_show quantumsavory_gabs_state">
    <style>
    .quantumsavory_gabs_state table { border-collapse: collapse; margin: 0.35rem 0 0.75rem; }
    .quantumsavory_gabs_state th, .quantumsavory_gabs_state td { border: 1px solid #c8c8d0; padding: 0.2rem 0.45rem; text-align: right; }
    .quantumsavory_gabs_state th:first-child, .quantumsavory_gabs_state td:first-child { text-align: left; }
    .quantumsavory_gabs_state .quantumsavory_gabs_diag { font-weight: 700; background: #f2f5ff; }
    </style>
    <h4>Gaussian state</h4>
    <p><b>Modes:</b> $(n) &nbsp; <b>Basis:</b> $(_gabs_basis_name(state)) &nbsp; <b>Purity:</b> $(_gabs_fmt(Gabs.purity(state)))</p>
    """)
    print(io, "<h5>First moments</h5>")
    _gabs_html_table(io, ("mode", "q", "p"), moment_rows; class = "quantumsavory_gabs_moments")
    print(io, "<h5>Per-mode covariance summary</h5>")
    _gabs_html_table(
        io,
        ("mode", "Var(q)", "Var(p)", "Cov(q,p)", "marginal purity"),
        marginal_rows;
        class = "quantumsavory_gabs_marginals",
    )
    print(io, "<h5>Covariance matrix</h5>")
    print(io, "<table class=\"quantumsavory_gabs_covariance\"><thead><tr><th></th>")
    for label in labels
        print(io, "<th>", label, "</th>")
    end
    print(io, "</tr></thead><tbody>")
    for (row, row_label) in enumerate(labels)
        print(io, "<tr><th>", row_label, "</th>")
        for col in eachindex(labels)
            class = row == col ? " class=\"quantumsavory_gabs_diag\"" : ""
            print(io, "<td", class, ">", _gabs_fmt(state.covar[row, col]), "</td>")
        end
        print(io, "</tr>")
    end
    print(io, "</tbody></table>")
    print(io, "<p><b>Max |inter-mode covariance|:</b> ", _gabs_fmt(_gabs_inter_mode_covariance(state)), "</p>")
    print(io, "</div>")
end
