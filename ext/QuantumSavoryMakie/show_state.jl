function Base.show(io::IO, m::MIME"image/png", s::StateRef)
    f = Figure()
    stateshowimage(f,QuantumSavory.quantumstate(s),s)
    show(io, m, f)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy. Instead of an IO instance, it takes a Makie figure."""
function stateshowimage(subfig, state::Gabs.GaussianState, stateref)
    nm = QuantumSavory.nsubsystems(state)
    a = Axis(subfig[1, 1], title="Covariance matrix ($nm mode$(nm == 1 ? "" : "s"))",
        aspect=Makie.DataAspect(), yreversed=true)
    max_val = max(1e-5, maximum(abs, state.covar))
    hm = heatmap!(a, state.covar, colormap=:RdBu, colorrange=(-max_val, max_val))
    Colorbar(subfig[1, 2], hm)
    _gabs_covariance_separators!(a, state.basis, nm)
    a2 = Axis(subfig[2, 1], title="First moments")
    barplot!(a2, 1:length(state.mean), state.mean)
    return subfig
end

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

function _gabs_covariance_separators!(a, ::Gabs.QuadBlockBasis, nm::Int)
    vlines!(a, nm + 0.5; color=(:black, 0.35), linestyle=:dash)
    hlines!(a, nm + 0.5; color=(:black, 0.35), linestyle=:dash)
    for k in 1:nm - 1
        vlines!(a, [k, nm + k] .+ 0.5; color=(:black, 0.2), linestyle=:dot)
        hlines!(a, [k, nm + k] .+ 0.5; color=(:black, 0.2), linestyle=:dot)
    end
end

function _gabs_covariance_separators!(a, basis, nm::Int)
    for k in 1:nm - 1
        boundary = 2k + 0.5
        vlines!(a, boundary; color=(:black, 0.35), linestyle=:dash)
        hlines!(a, boundary; color=(:black, 0.35), linestyle=:dash)
    end
end
