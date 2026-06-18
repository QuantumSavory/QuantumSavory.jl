_histogram_xticks(state::AbstractKet) = eachindex(state.data), [L"|%$(string(i-1; base=2, pad=nsubsystems(state)))\rangle" for i in eachindex(state.data)]
_histogram_xticks(state::AbstractBra) = eachindex(state.data), [L"\langle %$(string(i-1; base=2, pad=nsubsystems(state)))|" for i in eachindex(state.data)]
_histogram_xticks(state::AbstractOperator) = eachindex(state.data), [string(i-1; base=2, pad=nsubsystems(state)) for i in eachindex(state.data)]

function draw_histogram!(fig, state::StateVector)
    ax = Axis(fig[1,1];
        title = "State Amplitudes",
        xlabel = "Computational Basis State",
        ylabel = "|Amplitude|",
        xticks = _histogram_xticks(state),
        xticklabelrotation = π/2,
        xlabelpadding = 10,
        ylabelpadding = 10,
    )
    ylims!(ax, 0, 1)

    barplot!(ax, eachindex(state.data), abs.(state.data);
        color = angle.(state.data),
        colormap = :cyclic_mrybm_35_75_c68_n256,
        colorrange = (-π, π),
    )

    Colorbar(fig[1,2]; colorrange=(-π,π), colormap=:cyclic_mrybm_35_75_c68_n256, ticks=([-π,0,π],["-π","0","π"]), label="phase", vertical=true, labelpadding=-2)
end

function draw_histogram!(fig, state::AbstractOperator)
    ax = Axis(fig;
        title = "State Probabilities",
        xlabel = "Computational Basis State",
        ylabel = "Probability",
        xticks = _histogram_xticks(state),
        xticklabelrotation = π/2,
        xlabelpadding = 10,
        ylabelpadding = 10,
    )
    ylims!(ax, 0, 1)

    probs = real.(diag(state.data))
    barplot!(ax, eachindex(probs), probs)
end

function draw_stateinfo!(fig, state::Union{AbstractOperator, StateVector})
    ax = Axis(fig)
    hidedecorations!(ax)
    hidespines!(ax)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)

    text!(ax, 0.25, 0.5;
        text = rich(
            rich("Quantum State\n", font=:bold),
            "Type: $(nameof(typeof(state)))\n",
            "NSubsystems: $(nsubsystems(state))"
        ),
        align = (:center, :center)
    )

    text!(ax, 0.75, 0.5;
        text=rich(rich("State Properties\n", font=:bold),
            "Purity: $(@sprintf("%.3f", QuantumSavory.purity(state)))\n",
            "Entropy: $(@sprintf("%.3f", entropy_vn(state)/log(2)))",
        ),
        align=(:center, :center)
    )
end