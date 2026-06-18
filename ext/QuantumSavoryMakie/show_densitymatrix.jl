function draw2q_densitymatrix!(fig, state::AbstractOperator)
    ρticks = ((1:4).+0.5, ["00","10","01","11"])
    ρBticks = ((1:4).+0.5, ["Φ+","Φ-","Ψ+","Ψ-"])
    a3dρ = Axis3(fig[1,1],
        xticks=ρticks, yticks=ρticks, yreversed=true, zticks=([0,0.25,0.5,0.75,1],["","¼","½","¾","1"]),
        xlabel="", ylabel="", zlabel="",
        title="ρ (Z basis)", tellheight=true
    )
    a3dρB = Axis3(fig[1,2],
        xticks=ρBticks, yticks=ρBticks, yreversed=true, zticks=([0,0.25,0.5,0.75,1],["","¼","½","¾","1"]),
        xlabel="", ylabel="", zlabel="",
        title="ρ (Bell basis)", tellheight=true
    )
    xlims!(a3dρ,1-0.1,5)
    ylims!(a3dρ,5,1-0.1)
    xlims!(a3dρB,1-0.1,5)
    ylims!(a3dρB,5,1-0.1)
    zlims!(a3dρ,0,1)
    zlims!(a3dρB,0,1)

    ρdata = state.data
    ρBdata = (B*state*B').data
    meshscatter!(a3dρ, [Point3f(i,j,0) for i in 1:4 for j in 1:4];
        marker = Rect3f((0, 0, 0), (0.9, 0.9, 1)),
        markersize = [Vec3f(1, 1, abs(ρdata[i,j])) for i in 1:4 for j in 1:4],
        color = [angleifnotε(ρdata[i,j]) for i in 1:4 for j in 1:4],
        colorrange = (-π, π),
        colormap = :cyclic_mrybm_35_75_c68_n256,
    )
    meshscatter!(a3dρB, [Point3f(i,j,0) for i in 1:4 for j in 1:4];
        marker = Rect3f((0, 0, 0), (0.9, 0.9, 1)),
        markersize = [Vec3f(1, 1, abs(ρBdata[i,j])) for i in 1:4 for j in 1:4],
        color = [angleifnotε(ρBdata[i,j]) for i in 1:4 for j in 1:4],
        colorrange = (-π, π),
        colormap = :cyclic_mrybm_35_75_c68_n256,
    )
end
draw2q_densitymatrix!(fig, state::StateVector) = draw2q_densitymatrix!(fig, dm(state))

function draw2q_stateinfo!(subfig, state::Union{AbstractOperator, StateVector})
    ax = Axis(subfig)
    hidedecorations!(ax)
    hidespines!(ax)
    xlims!(ax, 0, 1)
    ylims!(ax, 0, 1)

    text!(ax, 0.25, 1;
        text = rich(
            rich("Quantum State\n", font=:bold),
            "Type: $(nameof(typeof(state)))\n",
            "Basis: $(basis(state))"
        ),
        align = (:center, :top)
    )

    text!(ax, 0.75, 1;
        text=rich(rich("State Properties\n", font=:bold),
            "Purity: $(@sprintf("%.3f", QuantumSavory.purity(state)))\n",
            "Entropy: $(@sprintf("%.3f", entropy_vn(state)/log(2)))",
        ),
        align=(:center, :top)
    )
end