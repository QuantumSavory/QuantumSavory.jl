function Base.show(io::IO, m::MIME"image/png", s::StateRef)
    f = Figure()  # no hardcoded size — let Makie use its default
    stateshowimage(f, QuantumSavory.quantumstate(s), s)
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
            barplot!(a_fm, [n,n], QuantumSavory._mode_mean(state, n, N), dodge=[1,2], width=0.85, color=[1,2], colormap=colors)
        end
        labels = [L"\langle \hat{x} \rangle", L"\langle \hat{p} \rangle"]
        elements = [PolyElement(color=colors[i]) for i in 1:length(labels)]
        Legend(subfig[1,4], elements, labels)
        hlines!(a_fm, [0], color = :black, linewidth = 1.5, linestyle=:dash)
    end
    # phase space ellipse for 1-mode state
    if N == 1
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

# Helper: is the state's basis SpinBasis(1//2)?
_is_spin_half_basis(s::QuantumOpticsBase.Ket) =
    s.basis isa SpinBasis && s.basis.spinnumber == 1//2
_is_spin_half_basis(s::QuantumOpticsBase.AbstractOperator) =
    s.basis_l isa SpinBasis && s.basis_l.spinnumber == 1//2

function stateshowimage(
        subfig,
        state::Union{<:QuantumOpticsBase.Ket, <:QuantumOpticsBase.AbstractOperator},
        stateref)
    dims = QuantumSavory._basis_dimensions(state)
    nsub = length(dims)
    N    = prod(dims)
    rows = QuantumSavory._top_probability_rows(state; topk=8)

    # Single spin-1/2 qubit: use QuantumOptics.qfuncsu2 for a proper 3D Bloch sphere
    if nsub == 1 && dims == [2] && _is_spin_half_basis(state) &&
            N <= QuantumSavory._QS_DISPLAY_MAX_DENSE_DIM
        _bloch_sphere_plot(subfig[1,1], state)
    elseif isempty(rows)
        a = Axis(subfig[1,1])
        hidedecorations!(a); hidespines!(a)
        text!(a, 0, 0;
              text  = "QuantumOpticsBase state\n(dim=$N — display suppressed)",
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

    # Summary text panel — include entanglement info if state spans multiple slots
    sa = Axis(subfig[1,2])
    hidedecorations!(sa); hidespines!(sa)
    lines_vec = QuantumSavory._stateref_summary_lines(state, stateref; topk=6)
    text!(sa, 0, 1; text=join(lines_vec, "\n"), align=(:left, :top), fontsize=13)
    xlims!(sa, 0, 1); ylims!(sa, 0, 1)
    subfig
end

# 3D Bloch sphere using QuantumOptics.jl's qfuncsu2 (Husimi Q-function on SU(2)).
# The Wigner quasi-probability function on SU(2) gives the coloring of the sphere surface.
function _bloch_sphere_plot(subfig, state)
    rho_op = state isa QuantumOpticsBase.Ket ? dm(state) : state

    # Use QuantumOptics.qfuncsu2 — Husimi Q-function on the SU(2) sphere.
    # wignersu2 has a known bounds error for spin-1/2 (N=1) in this version;
    # qfuncsu2 is the correct reuse of QuantumOptics.jl visualization capability.
    Ntheta = 40
    Nphi   = 2 * Ntheta
    Q = QuantumOptics.qfuncsu2(rho_op, Ntheta; Nphi=Nphi)  # Ntheta×Nphi real matrix

    # Build matching spherical coordinate grids (qfuncsu2 uses theta in [0,pi], phi in [0,2pi])
    thetas = range(0.0, π,  length=Ntheta)
    phis   = range(0.0, 2π, length=Nphi)
    xs = [sin(θ)*cos(φ) for θ in thetas, φ in phis]
    ys = [sin(θ)*sin(φ) for θ in thetas, φ in phis]
    zs = [cos(θ)        for θ in thetas, φ in phis]

    qmax = max(maximum(Q), 1e-10)

    ax = Axis3(subfig; title="Bloch sphere (Husimi Q function)",
               aspect=:equal, xlabel="X", ylabel="Y", zlabel="Z")
    surface!(ax, xs, ys, zs; color=Q, colormap=:viridis, colorrange=(0.0, qmax))

    # Overlay the Bloch vector as a line+point
    ρ  = Matrix(rho_op.data)
    bx = 2real(ρ[1,2])
    by = -2imag(ρ[1,2])
    bz = real(ρ[1,1]) - real(ρ[2,2])
    linesegments!(ax, [Point3f(0f0,0f0,0f0), Point3f(bx,by,bz)];
                  color=:black, linewidth=4)
    scatter!(ax, [Point3f(bx,by,bz)]; color=:black, markersize=12)

    xlims!(ax, -1.1, 1.1); ylims!(ax, -1.1, 1.1); zlims!(ax, -1.1, 1.1)
    ax
end
