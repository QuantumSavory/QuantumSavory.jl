function draw_amplhistogram!(fig, state::StateVector)
    data = state.data

    labels = [string(i-1; base=2, pad=nsubsystems(state)) for i in eachindex(data)]
    ax = Axis(fig[1,1], xticks=(eachindex(data), labels), xticklabelrotation=π/2)

    barplot!(
        ax,
        eachindex(data),
        abs.(data);
        color = angle.(data),
        colormap = :cyclic_mrybm_35_75_c68_n256,
        colorrange = (-π, π),
    )
end