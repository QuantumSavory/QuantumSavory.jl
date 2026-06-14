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
