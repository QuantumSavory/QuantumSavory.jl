function Base.show(io::IO, m::MIME"image/png", s::StateRef)
    f = Figure(size=(1000, 440))
    stateshowimage(f,QuantumSavory.quantumstate(s),s)
    show(io, m, f)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy. Instead of an IO instance, it takes a Makie axis."""
function stateshowimage(subfig, state, stateref)
    a = Axis(subfig[1,1])
    hidedecorations!(a)
    hidespines!(a)
    text = "state of type\n$(typeof(state))\ndoes not support rich visualization"
    text!(a,0,0;text,align=(:center,:center))
end

function stateshowimage(subfig, state::QuantumClifford.MixedDestabilizer, stateref)
    stab = QuantumClifford.stabilizerview(state)
    names = [
        QuantumSavory.namestr(s.reg,useobjectid=false)*".$(s.idx)"
        for s in QuantumSavory.slots(stateref)
        ]
    subfig,ax,p = QuantumClifford.stabilizerplot_axis(subfig, stab)
    #ax.xticksvisible = true
    ax.xticklabelsvisible = true
    ax.xticks = (1:length(names), names)
    ax.xticklabelrotation = pi/2*0.8
    ax.yticks = (Int[], String[])
    subfig
end

function stateshowimage(subfig, state::Gabs.GaussianState, stateref)
    # covariance matrix heatmap
    N = Gabs.nmodes(state)
    if typeof(state.basis) <: Gabs.QuadPairBasis
        ticks = (1:2N, vec(reduce(hcat, [[L"x_{%$i}", L"p_{%$i}"] for i in 1:N])))
    elseif typeof(state.basis) <: Gabs.QuadBlockBasis
        ticks = (1:2N, vcat([L"x_{%$i}" for i in 1:N], [L"p_{%$i}" for i in 1:N]))
    end
    resize!(subfig.scene, (800, 400))
    a_cv = Axis(
        subfig[1,1];
        aspect = Makie.DataAspect(),
        xaxisposition=:top,
        xticks=ticks,
        yticks=ticks,
        title="Covariance Matrix",
    )
    max_val = maximum(abs, state.covar)
    hm = heatmap!(a_cv, state.covar, colormap=:RdBu, colorrange=(-max_val, max_val))
    a_cv.yreversed = true
    Colorbar(subfig[1, 2], hm)
    # first moments barplot
    if !iszero(state.mean)
        a_fm = Axis(
            subfig[1,3];
            title="First Moments (Displacements)",
            xticks=(1:N, ["$i" for i in 1:N]),
            xlabel="Modes",
            ylabel="Amplitude",
        )
        colors = cgrad(:RdBu, 2, categorical=true)
        for n in 1:N
            barplot!(a_fm, [n,n], _mode_mean(state, n, N), dodge=[1,2], width=0.85, color=[1,2], colormap=colors)
        end
        labels = [L"\langle \hat{x} \rangle", L"\langle \hat{p} \rangle"]
        elements = [PolyElement(color=colors[i]) for i in 1:length(labels)]
        Legend(subfig[1,4], elements, labels)
        hlines!(a_fm, [0], color = :black, linewidth = 1.5, linestyle=:dash)
    end
    # phase space ellipse for 1-mode state
    if N == 1
        resize!(subfig.scene, (800, 800))
        λs, vecs = eigen(state.covar)
        a, b = sqrt.(λs)
        v1, v2 = vecs[:, 1], vecs[:, 2]
        ϕ = atan(v1[2], v1[1])
        t = range(0, 2pi; length=100)
        xs = @. a * cos(ϕ) * cos(t) - b * sin(ϕ) * sin(t) + state.mean[1]
        ps = @. a * sin(ϕ) * cos(t) + b * cos(ϕ) * sin(t) + state.mean[2]
        a_el = Axis(
            subfig[2, :];
            title="Phase Space Ellipse",
            aspect=1.0,
            xlabel=L"x",
            ylabel=L"p",
        )
        vlines!(a_el, [state.mean[1]], color = :black, linewidth = 1.5, linestyle=:dash)
        hlines!(a_el, [state.mean[2]], color = :black, linewidth = 1.5, linestyle=:dash)
        scatter!(a_el, Point2f(state.mean), color = :red, label="Mean")
        axislegend(position = :rb)
        lines!(a_el, Point2f.(xs, ps))
    end
end

function stateshowimage(
        subfig,
        state::Union{<:QuantumOpticsBase.Ket, <:QuantumOpticsBase.AbstractOperator},
        stateref)
    dims = QuantumSavory._basis_dimensions(state)
    rows = QuantumSavory._top_probability_rows(state; topk=8)

    if prod(dims) <= QuantumSavory._QS_DISPLAY_MAX_DENSE_DIM &&
            length(dims) == 1 && dims == [2]
        rho    = QuantumSavory._dense_density_matrix(state)
        paulis = QuantumSavory._pauli_expectations_from_density_matrix(rho)
        _bloch_vector_plot(subfig[1,1], [v for (_,v) in paulis])
    elseif isempty(rows)
        a = Axis(subfig[1,1])
        hidedecorations!(a); hidespines!(a)
        text!(a, 0, 0;
              text  = "QuantumOpticsBase state\n(no nonzero basis probabilities)",
              align = (:center, :center))
    else
        labels = [label for (label, _) in rows]
        probs  = [p     for (_,     p) in rows]
        a = Axis(subfig[1,1]; title="Top basis probabilities", ylabel="Probability")
        barplot!(a, 1:length(probs), probs)
        a.xticks             = (1:length(labels), labels)
        a.xticklabelrotation = pi/2 * 0.35
        ylims!(a, 0, max(1.0, maximum(probs) * 1.1))
    end

    sa = Axis(subfig[1,2])
    hidedecorations!(sa); hidespines!(sa)
    lines = QuantumSavory._stateref_summary_lines(state, stateref; topk=6)
    text!(sa, 0, 1; text=join(lines, "\n"), align=(:left, :top), fontsize=13)
    xlims!(sa, 0, 1); ylims!(sa, 0, 1)
    subfig
end

function _bloch_vector_plot(subfig, bloch)
    axis = Axis(subfig; title="Bloch vector (XY plane)", xlabel="X", ylabel="Y", aspect=1)
    θ    = range(0, 2π; length=121)
    lines!(axis, cos.(θ), sin.(θ); color=:gray70, linewidth=2)
    lines!(axis, [-1.0,  1.0], [0.0, 0.0]; color=:gray50, linewidth=1)
    lines!(axis, [ 0.0,  0.0], [-1.0, 1.0]; color=:gray50, linewidth=1)
    lines!(axis, [0.0, bloch[1]], [0.0, bloch[2]]; color=:crimson, linewidth=5)
    scatter!(axis, [bloch[1]], [bloch[2]]; color=:crimson, markersize=14)
    text!(axis, -0.95, 0.94;
          text  = "Z=$(QuantumSavory._format_real(bloch[3]))",
          align = (:left, :top), fontsize=13)
    text!(axis, -0.95, 0.80;
          text  = "|r|=$(QuantumSavory._format_real(sqrt(sum(abs2, bloch))))",
          align = (:left, :top), fontsize=13)
    xlims!(axis, -1.05, 1.05); ylims!(axis, -1.05, 1.05)
    axis
end
