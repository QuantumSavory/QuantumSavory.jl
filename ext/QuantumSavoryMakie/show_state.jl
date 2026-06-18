get_statedata(state::Ket) = state.data
get_statedata(state::Bra) = state.data
get_statedata(state::Operator) = state.data
get_statedata(state::LazyKet) = get_statedata(Ket(state))
get_statedata(state) = nothing

include("show_bloch.jl")
include("show_densitymatrix.jl")
include("show_amplhistogram.jl")

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

function stateshowimage(subfig, state::Union{AbstractOperator, StateVector}, stateref)
    set_theme!(theme_latexfonts())
    if nsubsystems(state) == 1
        update_theme!(Theme(figure_padding=0))
        draw1q_bloch!(subfig[1,1], state)
        draw1q_stateinfo!(subfig[1, 1:2], state)
        colgap!(subfig.layout, 0)
        colsize!(subfig.layout, 1, Relative(0.664))
    elseif nsubsystems(state) == 2
        update_theme!(Theme(figure_padding=0))
        draw2q_densitymatrix!(subfig, state)
        # also draw the colorbar and the stateinfo
        colgap!(subfig.layout, 0)
        # colsize!(subfig.layout, 1, Relative(0.664))
    elseif 3 <= nsubsystems(state) <= 5
        draw_amplhistogram!(subfig, state)
    else
        ax = Axis(subfig[1,1])
        hidedecorations!(ax)
        hidespines!(ax)
        text = "state of type\n$(typeof(state))\nwith $(nsubsystems(state)) subsystems\ndoes not support rich visualization"
        text!(ax,0,0;text,align=(:center,:center))
    end
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
