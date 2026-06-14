function stateshow(io, ::MIME"text/plain", state::Gabs.GaussianState, stateref::StateRef)
    print(io, "\n\nGaussian State")
    N = Gabs.nmodes(state)
    print(io, "\n  Modes: ", N)
    print(io, "\n  Basis: ", nameof(typeof(state.basis)))
    p = Gabs.purity(state)
    print(io, "\n  Purity: ", p ≈ 1.0 ? "1.0 (Pure State)" : p)
    if N > 1 && !iszero(state.mean)
        print(io, "\n\nDisplacement Vector (First Moments):")
        print(io, "\n  ", state.mean)
    end
    if N == 1
        print(io, "\n  Mean: ", _mode_mean(state, 1, N))
        print(io, "\n  Covariance Matrix:\n")
        Base.print_matrix(stdout, _mode_covariance(state, 1, N), "    ")
    elseif N > 1
        # [TODO] covariance matrix summary
        print(io, "\n\nPer-mode Marginals:")
        for n in 1:N
            covar = _mode_covariance(state, n, N)
            print(io, "\n  ", N > 1 ? "Mode $n: " : "")
            print(
                "Mean = $(_mode_mean(state, n, N))", " | ",
                "Var(x) = $(covar[1, 1])", " | ",
                "Var(p) = $(covar[2, 2])", " | ",
                "Purity = $(_mode_purity(covar))"
            )
        end
    end
end

function stateshow(io, ::MIME"text/html", state::Gabs.GaussianState, stateref::StateRef)
    N = Gabs.nmodes(state)
    basis = nameof(typeof(state.basis))
    p = Gabs.purity(state)
    first_moments = pretty_table(
        String,
        transpose(reduce(hcat, [_mode_mean(state, n, N) for n in 1:N]));
        backend = :html,
        table_class = "gabs_first_moments",
        column_labels = ["⟨x̂⟩", "⟨p̂⟩"],
        row_labels = ["Mode $i" for i in 1:N],
        row_label_column_alignment = :l,
        title = "First Moments",
    )
    covar_highlighters, covar_labels = _covariance_table_helper(state, N)
    print(io, """
    <div class="quantumsavory_gaussianstate">
    <h1><code>$N</code>-mode Gaussian state in <code>$basis</code> basis</h1>
    <dl>
    <dt>Purity</dt>
    <dd>$(p ≈ 1.0 ? "1.0 (Pure State)" : p)</dd>
    </dl>
    $first_moments
    $(pretty_table(
        String,
        state.covar;
        backend = :html,
        table_class = "gabs_covariance_matrix",
        column_labels = covar_labels,
        row_labels = covar_labels,
        highlighters = covar_highlighters,
        alignment = :c,
        title = "Covariance Matrix",
    ))
    </div>
    """)
end

function _mode_mean(state::Gabs.GaussianState{<:Gabs.QuadPairBasis,M,V}, n::Int64, N::Int64) where {M,V}
    return round.(state.mean[(2n-1):2n]; digits=5)
end

function _mode_mean(state::Gabs.GaussianState{<:Gabs.QuadBlockBasis,M,V}, n::Int64, N::Int64) where {M,V}
    return round.(state.mean[[n, N+n]]; digits=5)
end

function _mode_covariance(state::Gabs.GaussianState{<:Gabs.QuadPairBasis,M,V}, n::Int64, N::Int64) where {M,V}
    return round.(state.covar[(2n-1):2n, (2n-1):2n]; digits=5)
end

function _mode_covariance(state::Gabs.GaussianState{<:Gabs.QuadBlockBasis,M,V}, n::Int64, N::Int64) where {M,V}
    return round.(state.covar[[n, N+n], [n, N+n]]; digits=5)
end

function _mode_purity(covar::AbstractMatrix{Float64})
    return round(1 / (2 * sqrt(det(covar))); digits=5)
end

function _covariance_table_helper(state::Gabs.GaussianState{<:Gabs.QuadPairBasis,M,V}, N::Int64) where {M,V}
    # grey out the non-block-diagonal entries
    hl_blocks = PrettyTables.HtmlHighlighter(
        (data, i, j) -> mod1(i, N) != mod1(j, N),
        ["opacity" => "0.3"]
    )
    # bold the diagonal entries
    hl_diag = PrettyTables.HtmlHighlighter(
        (data, i, j) -> i == j,
        ["color" => "green"]
    )
    highlighters = [hl_blocks, hl_diag]
    labels = vec(reduce(hcat, [[_subscript("x", i), _subscript("p", i)] for i in 1:N]))
    return highlighters, labels
end

function _covariance_table_helper(state::Gabs.GaussianState{<:Gabs.QuadBlockBasis,M,V}, N::Int64) where {M,V}
    # grey out the non-block-diagonal entries
    hl_blocks = PrettyTables.HtmlHighlighter(
        (data, i, j) -> (i - 1) ÷ 2 != (j - 1) ÷ 2,
        ["opacity" => "0.3"]
    )
    # bold the diagonal entries
    hl_diag = PrettyTables.HtmlHighlighter(
        (data, i, j) -> i == j,
        ["color" => "green"]
    )
    highlighters = [hl_blocks, hl_diag]
    labels = vcat([_subscript("x", i) for i in 1:N], [_subscript("p", i) for i in 1:N])
    return highlighters, labels
end

# Convert an integer into a subscript string
function _subscript(s::String, i::Integer)
    subscript = join(Char(0x2080 + d) for d in digits(i))
    return join(vcat(s, subscript))
end
