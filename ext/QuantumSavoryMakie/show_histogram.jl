_histogram_xticks(state::AbstractKet, idxs::Vector) = eachindex(idxs), [L"|%$(string(i-1; base=2, pad=nsubsystems(state)))\rangle" for i in idxs]
_histogram_xticks(state::AbstractBra, idxs::Vector) = eachindex(idxs), [L"\langle %$(string(i-1; base=2, pad=nsubsystems(state)))|" for i in idxs]
_histogram_xticks(state::AbstractOperator, idxs::Vector) = eachindex(idxs), [string(i-1; base=2, pad=nsubsystems(state)) for i in idxs]

function draw_histogram!(fig, state::StateVector)
    amps = collect(enumerate(state.data))
    if nsubsystems(state) > 5
        sort!(amps; by = x -> abs(x[2]), rev = true)
        amps = amps[1:min(8, length(amps))]
        title = "Top $(length(amps)) Amplitudes"
    else
        title = "State Amplitudes"
    end

    ax = Axis(fig[1,1];
        title = title,
        xlabel = "Computational Basis State",
        ylabel = "|Amplitude|",
        xticks = _histogram_xticks(state, first.(amps)),
        xticklabelrotation = π/2,
        xlabelpadding = 10,
        ylabelpadding = 10,
    )
    ylims!(ax, 0, 1)

    barplot!(ax, eachindex(amps), abs.(last.(amps));
        color = angle.(last.(amps)),
        colormap = :cyclic_mrybm_35_75_c68_n256,
        colorrange = (-π, π),
    )

    Colorbar(fig[1,2]; colorrange=(-π,π), colormap=:cyclic_mrybm_35_75_c68_n256, ticks=([-π,0,π],["-π","0","π"]), label="phase", vertical=true, labelpadding=-2)
end

function draw_histogram!(fig, state::AbstractOperator)
    probs = collect(enumerate(real.(diag(state.data))))
    if nsubsystems(state) > 5
        sort!(probs; by = x -> x[2], rev = true)
        probs = probs[1:min(8, length(probs))]
        title = "Top $(length(probs)) Probabilities"
    else
        title = "State Probabilities"
    end

    ax = Axis(fig;
        title = title,
        xlabel = "Computational Basis State",
        ylabel = "Probability",
        xticks = _histogram_xticks(state, first.(probs)),
        xticklabelrotation = π/2,
        xlabelpadding = 10,
        ylabelpadding = 10,
    )
    ylims!(ax, 0, 1)

    barplot!(ax, eachindex(probs), last.(probs))
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