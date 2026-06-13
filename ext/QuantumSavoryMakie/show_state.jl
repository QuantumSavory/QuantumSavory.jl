function Base.show(io::IO, m::MIME"image/png", s::StateRef)
    f = Figure()
    stateshowimage(f,QuantumSavory.quantumstate(s),s)
    show(io, m, f)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy. Instead of an IO instance, it takes a Makie axis."""
function stateshowimage(subfig, state, stateref)
    a = Axis(subfig[1, 1])
    hidedecorations!(a)
    hidespines!(a)
    text = "state of type\n$(typeof(state))\ndoes not support rich visualization"
    text!(a, 0, 0; text=text, align=(:center, :center))
end

function stateshowimage(subfig, state::QuantumClifford.MixedDestabilizer, stateref)
    stab = QuantumClifford.stabilizerview(state)
    names = [
        QuantumSavory.namestr(s.reg, useobjectid=false)*".$(s.idx)"
        for s in QuantumSavory.slots(stateref)
        ]
    subfig, ax, p = QuantumClifford.stabilizerplot_axis(subfig, stab)
    ax.xticklabelsvisible = true
    ax.xticks = (1:length(names), names)
    ax.xticklabelrotation = pi/2 * 0.8
    ax.yticks = (Int[], String[])
    subfig
end

function stateshowimage(subfig, state::Ket, stateref)
    QuantumSavory._is_qubit_state(state) || return _stateshowimage_fallback(subfig, state)
    n = QuantumSavory._nqubits_qo(state)
    ρ = QuantumSavory._to_dm(state)
    if n == 1
        _plot_1q(subfig, ρ)
    elseif n == 2
        _plot_2q(subfig, ρ)
    elseif n <= QuantumSavory._DENSE_VIS_CUTOFF
        _plot_nq(subfig, state, ρ, n)
    else
        _plot_large(subfig, state, ρ, n)
    end
end

function stateshowimage(subfig, state::Operator, stateref)
    QuantumSavory._is_qubit_state(state) || return _stateshowimage_fallback(subfig, state)
    n = QuantumSavory._nqubits_qo(state)
    if n == 1
        _plot_1q(subfig, state)
    elseif n == 2
        _plot_2q(subfig, state)
    elseif n <= QuantumSavory._DENSE_VIS_CUTOFF
        _plot_nq(subfig, nothing, state, n)
    else
        _plot_large(subfig, nothing, state, n)
    end
end

function _stateshowimage_fallback(subfig, state)
    a = Axis(subfig[1, 1])
    hidedecorations!(a)
    hidespines!(a)
    text = "state of type\n$(typeof(state))\ndoes not support rich visualization"
    text!(a, 0, 0; text=text, align=(:center, :center))
end

function _plot_1q(subfig, ρ)
    rx, ry, rz = QuantumSavory._bloch_vector(ρ)
    p = QuantumSavory._purity(ρ)
    ex, ey, ez = QuantumSavory._pauli_expectations_1q(ρ)
    S = QuantumSavory._von_neumann_entropy(ρ)

    a3 = Axis3(subfig[1,1], aspect=:data,
        xlabel="X", ylabel="Y", zlabel="Z",
        title="Bloch sphere")

    θ = range(0, 2π, length=60)
    φ = range(0, π, length=30)
    xs = [sin(p)*cos(t) for t in θ, p in φ]
    ys = [sin(p)*sin(t) for t in θ, p in φ]
    zs = [cos(p) for _ in θ, p in φ]
    Makie.wireframe!(a3, xs, ys, zs, color=(:gray80, 0.3), linewidth=0.3)

    for (circle_xs, circle_ys, circle_zs) in [
        (cos.(θ), sin.(θ), zeros(length(θ))),
        (cos.(θ), zeros(length(θ)), sin.(θ)),
        (zeros(length(θ)), cos.(θ), sin.(θ))
    ]
        lines!(a3, circle_xs, circle_ys, circle_zs, color=:gray60, linewidth=0.8)
    end

    lines!(a3, [0, rx], [0, ry], [0, rz], color=:red, linewidth=3)
    scatter!(a3, [rx], [ry], [rz], color=:red, markersize=12)
    xlims!(a3, -1.2, 1.2)
    ylims!(a3, -1.2, 1.2)
    zlims!(a3, -1.2, 1.2)

    info = subfig[1,2]
    Label(info[1,1],
        "⟨X⟩ = $(@sprintf "%.4f" ex)\n⟨Y⟩ = $(@sprintf "%.4f" ey)\n⟨Z⟩ = $(@sprintf "%.4f" ez)\nPurity = $(@sprintf "%.4f" p)\nEntropy = $(@sprintf "%.4f" S) bits",
        tellwidth=false, tellheight=false, halign=:left, valign=:top,
        fontsize=12)
end

function _plot_2q(subfig, ρ)
    m = QuantumSavory._dm_matrix(ρ)
    p = QuantumSavory._purity(ρ)
    S = QuantumSavory._von_neumann_entropy(ρ)

    colormap = :cyclic_mrybm_35_75_c68_n256
    colorrange = (-pi, pi)
    ρticks = ((1:4) .+ 0.5, ["00", "10", "01", "11"])

    a3d = Axis3(subfig[1, 1],
        xticks=ρticks, yticks=ρticks, yreversed=true,
        zticks=([0, 0.25, 0.5, 0.75, 1], ["", "¼", "½", "¾", "1"]),
        xlabel="", ylabel="", zlabel="",
        title="ρ (Z basis)")
    xlims!(a3d, 0.9, 5)
    ylims!(a3d, 5, 0.9)
    zlims!(a3d, -0.001, 1.001)

    for i in 1:4, j in 1:4
        val = m[i, j]
        mesh!(a3d, Rect3f(i, j, 0, 0.9, 0.9, abs(val) + 1e-4);
            color = angle(val) * (abs(val) < 0.001 ? 0.0 : 1.0), colorrange=colorrange, colormap=colormap)
    end

    Colorbar(subfig[1, 2]; colorrange=colorrange, colormap=colormap,
        ticks=([-π, 0, π], ["-π", "0", "π"]), label="phase", tellheight=false)

    Label(subfig[2,1],
        "Purity = $(@sprintf "%.4f" p)   Entropy = $(@sprintf "%.4f" S) bits",
        tellwidth=false, fontsize=12)
end

function _plot_nq(subfig, ψ, ρ, n)
    dim = 2^n
    p = QuantumSavory._purity(ρ)
    S = QuantumSavory._von_neumann_entropy(ρ)
    labels = QuantumSavory._basis_labels(n)

    if !isnothing(ψ) && ψ isa Ket
        v = QuantumSavory._state_vector(ψ)
        mags = abs.(v)
        phases = angle.(v)

        colormap = :cyclic_mrybm_35_75_c68_n256
        colorrange = (-pi, pi)

        a = Axis(subfig[1, 1],
            xticks=(1:dim, labels), xticklabelrotation=π/3,
            ylabel="Amplitude", title="$n-qubit state")
        Makie.barplot!(a, 1:dim, mags, color=phases, colormap=colormap, colorrange=colorrange)
        Colorbar(subfig[1, 2]; colorrange=colorrange, colormap=colormap,
            ticks=([-π, 0, π], ["-π", "0", "π"]), label="phase", tellheight=false)
    else
        diag = real.([ρ.data[i, i] for i in 1:dim])
        a = Axis(subfig[1, 1],
            xticks=(1:dim, labels), xticklabelrotation=π/3,
            ylabel="Probability", title="$n-qubit state")
        Makie.barplot!(a, 1:dim, diag, color=:steelblue)
    end

    Label(subfig[2,1],
        "Purity = $(@sprintf "%.4f" p)   Entropy = $(@sprintf "%.4f" S) bits",
        tellwidth=false, fontsize=12)
end

function _plot_large(subfig, ψ, ρ, n)
    a = Axis(subfig[1,1])
    hidedecorations!(a)
    hidespines!(a)

    lines = ["$n-qubit state"]
    push!(lines, "Hilbert space dimension: $(2^n)")
    if !isnothing(ρ)
        push!(lines, "Purity: $(@sprintf "%.6f" QuantumSavory._purity(ρ))")
        push!(lines, "Entropy: $(@sprintf "%.4f" QuantumSavory._von_neumann_entropy(ρ)) bits")
    end
    k = 8
    if !isnothing(ψ) && ψ isa Ket
        top = QuantumSavory._top_amplitudes(ψ, k)
        push!(lines, "Top-$k amplitudes:")
        for (label, amp) in top
            push!(lines, "  |$label⟩  prob=$(@sprintf "%.6f" abs2(amp))")
        end
    elseif !isnothing(ρ)
        top = QuantumSavory._top_probabilities(ρ, k)
        push!(lines, "Top-$k probabilities:")
        for (label, prob) in top
            push!(lines, "  |$label⟩  prob=$(@sprintf "%.6f" prob)")
        end
    end

    text!(a, 0, 0; text=join(lines, "\n"), align=(:center,:center), fontsize=11)
end
