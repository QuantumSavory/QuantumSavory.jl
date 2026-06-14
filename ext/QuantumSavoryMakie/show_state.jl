function Base.show(io::IO, m::MIME"image/png", s::StateRef)
    f = Figure(size=(1000, 440))
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

function stateshowimage(subfig, state::Union{<:QuantumOpticsBase.Ket,<:QuantumOpticsBase.Operator}, stateref)
    rows = QuantumSavory._top_probability_rows(state; topk=8)
    labels = [label for (label, _) in rows]
    probs = [prob for (_, prob) in rows]
    dims = QuantumSavory._basis_dimensions(state)
    mat = prod(dims) <= QuantumSavory._QS_DISPLAY_MAX_DENSE_DIM ? QuantumSavory._dense_density_matrix(state) : nothing

    if !isnothing(mat) && nsubsystems(state) == 1 && dims == [2] && size(mat) == (2, 2)
        paulis = QuantumSavory._pauli_expectations_from_density_matrix(mat)
        _bloch_vector_plot(subfig[1,1], [val for (_, val) in paulis])
    elseif isempty(rows)
        a = Axis(subfig[1,1])
        hidedecorations!(a)
        hidespines!(a)
        text!(a,0,0;text="QuantumOpticsBase state\n(no nonzero basis probabilities)",align=(:center,:center))
    else
        a = Axis(subfig[1,1], title="Top basis probabilities", ylabel="probability")
        barplot!(a, 1:length(probs), probs)
        a.xticks = (1:length(labels), labels)
        a.xticklabelrotation = pi/2*0.35
        ylims!(a, 0, max(1.0, maximum(probs) * 1.1))
    end

    summary_axis = Axis(subfig[1,2])
    hidedecorations!(summary_axis)
    hidespines!(summary_axis)
    summary = join(QuantumSavory._stateref_summary_lines(state, stateref; topk=6), "\n")
    text!(summary_axis, 0, 1; text=summary, align=(:left,:top), fontsize=13)
    xlims!(summary_axis, 0, 1)
    ylims!(summary_axis, 0, 1)
    subfig
end

function _bloch_vector_plot(subfig, bloch)
    axis = Axis(subfig, title="Bloch vector", xlabel="X", ylabel="Y", aspect=1)
    circle = range(0, 2pi; length=121)
    lines!(axis, cos.(circle), sin.(circle); color=:gray70, linewidth=2)
    lines!(axis, [-1, 1], [0, 0]; color=:gray50, linewidth=1)
    lines!(axis, [0, 0], [-1, 1]; color=:gray50, linewidth=1)
    lines!(axis, [0, bloch[1]], [0, bloch[2]]; color=:crimson, linewidth=5)
    scatter!(axis, [bloch[1]], [bloch[2]]; color=:crimson, markersize=14)
    text!(axis, -0.95, 0.94; text="Z=$(QuantumSavory._format_real(bloch[3]))", align=(:left,:top), fontsize=13)
    text!(axis, -0.95, 0.8; text="|r|=$(QuantumSavory._format_real(sqrt(sum(abs2, bloch))))", align=(:left,:top), fontsize=13)
    xlims!(axis, -1.05, 1.05)
    ylims!(axis, -1.05, 1.05)
    axis
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
