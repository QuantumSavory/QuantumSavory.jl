include("show_bloch.jl")
include("state_explorer.jl") # must put in its own file - use better naming

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
    update_theme!(Theme(figure_padding=0))
    if nsubsystems(state) == 1
        draw_bloch!(subfig[1,1], state)
        draw_stateinfo!(subfig[1, 1:2], state)
        colgap!(subfig.layout, 0)
        colsize!(subfig.layout, 1, Relative(0.664))
    elseif nsubsystems(state) == 2
        draw_state!(subfig, state)
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
