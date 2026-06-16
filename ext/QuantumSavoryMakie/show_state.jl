# ── PNG display for QuantumOptics states  (closes gap in #401) ───────────────

function Base.show(io::IO, ::MIME"image/png", s::StateRef)
    st = s.state[]
    if st === nothing
        _png_empty_slot(io)
        return
    end

    # QuantumClifford path – already handled by existing tableau plot
    if applicable(stabilizerview, st)
        _show_clifford_png(io, st)   # existing function
        return
    end

    # QuantumOptics path – new
    if applicable(dm, st) || (applicable(basis, st) && applicable(diag, st))
        _show_qo_png(io, st)
        return
    end

    # Generic fallback
    _png_no_display(io, typeof(st))
end

function _show_qo_png(io::IO, state)
    ρ_op = (state isa Operator) ? state : dm(state)
    ρ    = ρ_op.data
    N    = size(ρ, 1)
    n    = round(Int, log2(N))

    fig = Figure(resolution=(600, 300))

    if n == 1
        # Bloch sphere + density-matrix numeric panel (two axes side by side)
        ax_bloch = Axis3(fig[1, 1], title="Bloch sphere", aspect=:equal,
                         xlabel="X", ylabel="Y", zlabel="Z")
        bx, by, bz = _bloch_from_dm2(ρ)
        # draw sphere wireframe
        θs = range(0, 2π, 40)
        φs = range(0, π, 20)
        xs = [cos(θ)*sin(φ) for θ in θs, φ in φs]
        ys = [sin(θ)*sin(φ) for θ in θs, φ in φs]
        zs = [cos(φ)        for θ in θs, φ in φs]
        surface!(ax_bloch, xs, ys, zs, alpha=0.05, colormap=:greys)
        # draw Bloch vector
        arrows!(ax_bloch, [0], [0], [0], [bx], [by], [bz],
                color=:purple, arrowsize=0.08, linewidth=3)
        # text summary
        ax_txt = Axis(fig[1, 2], title="Summary", aspect=DataAspect())
        hidedecorations!(ax_txt); hidespines!(ax_txt)
        p  = sum(abs2, eigvals(ρ))
        S  = -sum(λ*log(max(λ,1e-300)) for λ in max.(0.0,real.(eigvals(ρ))) if λ>1e-14; init=0.0)
        summary_str = """
        n = 1 qubit
        purity  = $(round(real(p),digits=4))
        entropy = $(round(S,digits=4)) nat
        ⟨X⟩ = $(round(bx,digits=4))
        ⟨Y⟩ = $(round(by,digits=4))
        ⟨Z⟩ = $(round(bz,digits=4))
        """
        text!(ax_txt, 0.05, 0.95, text=summary_str, align=(:left,:top), fontsize=12)
    else
        # For 2+ qubits: probability bar chart
        probs  = real.(diag(ρ))
        labels = [_ket_label(i-1, n) for i in 1:length(probs)]
        k      = min(RICH_DISPLAY_TOP_K, length(probs))
        ord    = sortperm(probs, rev=true)[1:k]
        ax = Axis(fig[1, 1], title="Top-$k basis probabilities  (n=$n qubits)",
                  xlabel="basis state", ylabel="probability",
                  xticks=(1:k, labels[ord]))
        barplot!(ax, 1:k, probs[ord], color=:mediumpurple)
        p = sum(abs2, max.(0.0, real.(eigvals(ρ))))
        S = -sum(λ*log(max(λ,1e-300)) for λ in max.(0.0,real.(eigvals(ρ))) if λ>1e-14; init=0.0)
        ax2 = Axis(fig[1, 2], title="State info", aspect=DataAspect())
        hidedecorations!(ax2); hidespines!(ax2)
        text!(ax2, 0.05, 0.95,
              text="n = $n qubits\npurity = $(round(p,digits=4))\nentropy = $(round(S,digits=4)) nat",
              align=(:left,:top), fontsize=12)
    end

    save(io, fig)
end