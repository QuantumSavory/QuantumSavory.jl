function Base.show(io::IO, m::MIME"image/png", s::StateRef)
    f = Figure()
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
    labels = QuantumSavory._gabs_quadrature_labels(state)
    covar = Matrix(state.covar)
    ax = Axis(subfig[1, 1], title = "Gaussian covariance")
    hm = Makie.heatmap!(ax, 1:length(labels), 1:length(labels), covar; colormap = :balance)
    ax.xticks = (1:length(labels), labels)
    ax.yticks = (1:length(labels), labels)
    ax.xticklabelrotation = pi / 4
    Colorbar(subfig[1, 2], hm)

    mean = collect(state.mean)
    if any(!iszero, mean)
        ax_mean = Axis(subfig[2, 1], title = "First moments")
        Makie.barplot!(ax_mean, 1:length(mean), mean)
        ax_mean.xticks = (1:length(labels), labels)
        ax_mean.xticklabelrotation = pi / 4
        hlines!(ax_mean, [0], color = :gray60, linewidth = 1)
    end
    subfig
end
