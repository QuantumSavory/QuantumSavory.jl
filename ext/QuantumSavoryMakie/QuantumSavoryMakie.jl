module QuantumSavoryMakie

using QuantumSavory
using Graphs
using NetworkLayout
using ConcurrentSim: ConcurrentSim
using Makie: Makie, Theme, Figure, Axis, Axis3, Label, get_scene,
    @recipe, lift, @lift, Observable,
    Point2, Point2f, Rect2f, Rect3f,
    scatter!, poly!, linesegments!, lines!, hlines!, vlines!, mesh!, text!,
    xlims!, ylims!, zlims!,
    xticks!, yticks!,
    hidedecorations!, hidespines!,
    deregister_interaction!, interactions,
    DataInspector, Slider, Colorbar, axislegend

import QuantumSavory: registernetplot, registernetplot!, registernetplot_axis, resourceplot_axis, showonplot, showmetadata, stateof
using QuantumSavory: compactstr, peektags
using QuantumSavory.ProtocolZoo: ProtocolZoo, EntanglerProt, EntanglementConsumer

using QuantumClifford: QuantumClifford
using QuantumOpticsBase: QuantumOpticsBase, dm

## Color map for tag types — used to assign a deterministic color to each tag symbol
const TAG_COLORS = Dict{Symbol, Any}(
    :EntanglementCounterpart => :green,
    :EntanglementHistory    => :orange,
    :fid_pair               => :cyan,
    :measured               => :magenta,
    :heralded               => :purple,
    :LinkLayer              => :teal,
)
const TAG_FALLBACK_COLOR = :gray70
const TAG_MARKER_SHAPES = Dict{Symbol, Symbol}(
    :EntanglementCounterpart => :star4,
    :EntanglementHistory    => :diamond,
    :fid_pair               => :circle,
    :measured               => :xcross,
    :heralded               => :cross,
    :LinkLayer              => :hexagon,
)
const TAG_FALLBACK_SHAPE = :rect

## Pre-computed Pauli operators for Bloch-vector extraction
const σX_MAT = [0 1; 1 0]
const σY_MAT = [0 -im; im 0]
const σZ_MAT = [1 0; 0 -1]

"""
Extract a "Bloch-like" vector for any 2×2 density matrix.
Returns (x, y, z) or `nothing` if the state is not a single qubit
or the density matrix cannot be extracted.
"""
function bloch_components(state)
    ρ = try
        dm(state)
    catch
        return nothing
    end
    # Get the raw matrix data — handle both Operator types and plain matrices
    ρmat = try
        ρ.data
    catch
        ρ isa AbstractMatrix ? ρ : return nothing
    end
    size(ρmat) != (2, 2) && return nothing
    x = real(tr(ρmat * σX_MAT))
    y = real(tr(ρmat * σY_MAT))
    z = real(tr(ρmat * σZ_MAT))
    return (x, y, z)
end

"""
Extract a short human-readable description of the state stored in a `StateRef`.
Returns a multi-line string.
"""
function state_tooltip(stateref::StateRef)
    state = QuantumSavory.quantumstate(stateref)
    isnothing(state) && return "empty slot"
    lines = String[]
    try
        nsub = QuantumSavory.nsubsystems(state)
        push!(lines, "$nsub-subsystem state ($(typeof(state).name.module))")
    catch
        push!(lines, "state ($(typeof(state).name.module))")
    end
    # Attempt Bloch-vector extraction for single-qubit states
    bloch = bloch_components(state)
    if !isnothing(bloch)
        x, y, z = bloch
        push!(lines, "  Bloch: X=$(round(x; digits=3)) Y=$(round(y; digits=3)) Z=$(round(z; digits=3))")
    else
        # Show density matrix diagonal (occupation numbers) for larger systems
        try
            ρ = dm(state)
            diag_el = real.(diag(ρ.data))
            if length(diag_el) <= 8
                diag_str = join(round.(diag_el; digits=3), ", ")
                push!(lines, "  diag(ρ) = [$diag_str]")
            end
        catch
        end
    end
    # Show entangled partners
    try
        slots = QuantumSavory.slots(stateref)
        if length(slots) > 1
            partners = String[]
            for (i, s) in enumerate(slots)
                push!(partners, "  ↕ slot $(s.idx) @ $(compactstr(s.reg))")
            end
            push!(lines, "  entangled subsystems:")
            append!(lines, partners)
        end
    catch
    end
    return join(lines, "\n")
end

"""
Return a single-character / short-string summary of a `Tag` for use as
a visual marker.
"""
function tag_short_label(tag::Tag)
    # The first element of the payload is the descriptor (Symbol or DataType)
    descr = tag[1]
    if descr isa Symbol
        return String(descr)
    elseif descr isa DataType
        return string(nameof(descr))
    else
        return string(descr)
    end
end

"""
Determine marker shape and colour for a given tag.
"""
function tag_marker_style(tag::Tag)
    descr = tag[1]
    sym = if descr isa Symbol
        descr
    elseif descr isa DataType
        nameof(descr)
    else
        nothing
    end
    color = get(TAG_COLORS, sym, TAG_FALLBACK_COLOR)
    shape = get(TAG_MARKER_SHAPES, sym, TAG_FALLBACK_SHAPE)
    return (; color, shape)
end

##

"""
    get_messagebuffer_string(net::RegisterNet, regidx::Int) -> String

Return a tooltip string summarising the classical messages buffered
for the register at index `regidx` in `net`.
"""
function get_messagebuffer_string(net::RegisterNet, regidx::Int)
    if !haskey(net.cbuffers, regidx)
        return "  no message buffer"
    end
    mb = net.cbuffers[regidx]
    buf = mb.buffer
    if isempty(buf)
        return "  empty message buffer"
    end
    lines = String[]
    push!(lines, "  message buffer ($(length(buf)) pending):")
    for (j, entry) in enumerate(buf)
        src = entry.src
        tag_str = sprint(show, entry.tag; context=:compact=>true)
        push!(lines, "    [$j] from node $(src): $(tag_str)")
    end
    return join(lines, "\n")
end

"""
    get_qchannel_string(net::RegisterNet, src::Int, dst::Int) -> String

Return a tooltip string summarising the quantum states in flight
on the channel from `src` to `dst` in `net`.
"""
function get_qchannel_string(net::RegisterNet, src::Int, dst::Int)
    pair = src=>dst
    if !haskey(net.qchannels, pair)
        return "  no quantum channel"
    end
    qc = net.qchannels[pair]
    try
        q = qc.queue
        store = q.store
        items = collect(store.items)
        if isempty(items)
            return "  empty quantum channel"
        end
        lines = String[]
        push!(lines, "  quantum channel ($(length(items)) in flight):")
        for (j, reg) in enumerate(items)
            nsub = QuantumSavory.nsubsystems(reg)
            push!(lines, "    [$j] $(nsub)-subsystem state")
        end
        return join(lines, "\n")
    catch
        return "  quantum channel (inaccessible)"
    end
end


@recipe(RegisterNetPlot, regnet) do scene
    Theme(
        colormap = :Spectral,
        colorrange = (-1., 1.),
        register_color = :gray90,
        slotcolor = :gray60,
        slotmarker = :rect,
        scale = 1.0,
        slotsize = 0.8,
        observables_marker = :circle,
        observables_markersize = 0.55,
        observables_linewidth = 5,
        state_markersize = 0.4,
        state_marker = :diamond,
        state_markercolor = :black,
        state_linecolor = :gray90,
        lock_marker = '⚿',
        registercoords = nothing,
        observables = nothing,
        # --- New theme attributes for tag markers ---
        tag_markers_enabled = true,          # show tag markers on the plot
        tag_markersize = 0.2,
        tag_label_enabled = false,           # show short text labels next to markers
        # --- New theme attributes for message buffers ---
        mb_markers_enabled = true,           # show message-buffer count dots
        mb_markersize = 0.12,
        # --- New theme attributes for quantum channel states ---
        qch_markers_enabled = true,          # show in-flight quantum states along edges
        qch_markersize = 0.15,
    )
end

function Makie.plot!(rn::RegisterNetPlot{<:Tuple{RegisterNet}})
    networkobs = rn[1]
    network = networkobs[]
    registers = network.registers

    register_rectangles = Observable(Rect2f[])     # Makie rectangles that will be plotted for each register
    register_slots_coords = Observable(Point2f[])  # Makie marker locations that will be plotted for each register slot
    state_coords = Observable(Point2f[])           # Makie marker locations for each slot that contains a state subsystem
    lock_coords = Observable(Point2f[])            # Makie marker locations for each lock
    state_links = Observable(Point2f[])            # The lines connecting the state subsystem markers corresponding to the same composite system
    observables_coords = Observable(Point2f[])     # Makie marker locations that will be plotted for each subsystem on which an observable is evaluated
    observables_links = Observable(Point2f[])      # The links between observed subsystems
    observables_vals = Observable(Float64[])       # Values of the observables (stored per marker)
    observables_linkvals = Observable(Float64[])   # Values of the observables (stored per link)
    register_backref = Observable(Any[])           # A backreference to the register object for register square
    register_slots_coords_backref = Observable(Tuple{Any,Int,Int}[]) # A backreference to the register object and reference indices for each register slot marker
    state_coords_backref = Observable(Tuple{Any,Any,Int,Int,Int}[])  # A backreference to the state object and register object and reference indices for each state marker
    observables_backref = Observable(Tuple{Any,Float64}[])           # A backreference to the observable (and its value) for each colored dot visualizing an observable
    observables_links_backref = Observable(Tuple{Any,Float64}[])     # same as above but for the links

    # ---- NEW: tag marker observables (#66) ----
    tag_marker_coords   = Observable(Point2f[])   # positions of tag indicators
    tag_marker_colors   = Observable(Symbol[])     # colors for each tag marker
    tag_marker_shapes   = Observable(Symbol[])     # shapes for each tag marker
    tag_marker_labels   = Observable(String[])     # short labels
    tag_marker_backref  = Observable(Tuple{Int,Int,Tag}[])  # (registeridx, slot, tag)

    # ---- NEW: message-buffer observables (#96) ----
    mb_dot_coords       = Observable(Point2f[])   # positions for small dots counting messages
    mb_dot_counts       = Observable(Int[])        # number of buffered messages

    # ---- NEW: quantum-channel state observables (#97) ----
    qch_state_coords    = Observable(Point2f[])   # positions along edges for in-flight states
    qch_state_backref   = Observable(Tuple{Int,Int,Int}[])  # (src, dst, idx_in_queue)

    _extras = Dict{Symbol, Any}(
        :register_backref => register_backref,
        :register_slots_coords_backref => register_slots_coords_backref,
        :state_coords_backref => state_coords_backref,
        :observables_backref => observables_backref,
        :observables_links_backref => observables_links_backref,
        # NEW extras
        :tag_marker_backref => tag_marker_backref,
        :mb_dot_counts => mb_dot_counts,
        :qch_state_backref => qch_state_backref,
    )

    # Optional arguments
    ## registercoords -- updates handled explicitly by an `onany` call below
    if !isnothing(rn[:registercoords][])
        registercoords = rn[:registercoords][]
        registercoords isa Vector{<:Point2} || throw(ArgumentError("While plotting a network layout an incorrect argument was given: `registercoords` has to be of type `Vector{<:Point2}`. You can leave it empty to autogenerate a register layout. You can generate it manually or with packages like `NetworkLayout`."))
    else
        adj_matrix = adjacency_matrix(networkobs[].graph)
        registercoords = spring(adj_matrix, iterations=400, C=2*maximum(nsubsystems.(registers)))
        rn.registercoords[] = registercoords
    end
    ## slotcolor -- updates handled implicitly (used only in a single `scatter` call)
    slotcolor_resolved = if rn[:slotcolor][] isa Vector{<:Vector} # A vector of vector of colors (i.e. a vector of colors per register)
        lift(x->reduce(vcat, x), rn[:slotcolor]) # Turn it into a vector of colors
    else
        rn[:slotcolor]
    end
    ## observables -- updates handled explicitly by an `onany` call below
    if !isnothing(rn[:observables][])
        observablesval = rn[:observables][]
        if observablesval isa Vector{<:Tuple{Any,Tuple{Vararg{Tuple{Int,Int}}}}}
            observables = Tuple{Any, Tuple{Vararg{Tuple{Int,Int}}}, Vector{Tuple{Int,Int}}}[]
            for (O, rsidx) in observablesval
                links = Tuple{Int,Int}[]
                if length(rsidx)>1
                    for (i, (iʳᵉᵍ, iˢˡᵒᵗ)) in enumerate(rsidx)
                        push!(links, (iʳᵉᵍ, iˢˡᵒᵗ))
                        i == 1 || i == length(rsidx) || push!(links, (iʳᵉᵍ, iˢˡᵒᵗ))
                    end
                end
                push!(observables, (O, rsidx, links))
            end
            rn.observables[] = observables
        elseif observablesval isa Vector{<:Tuple{Any,Tuple{Vararg{Tuple{Int,Int}}},Vector{Tuple{Int,Int}}}}
            # the expected most general format
        else
            throw(ArgumentError("While plotting a network layout an incorrect argument was given: `observables` has to be of type `Vector{<:Tuple{Any, Tuple{...}}}`, i.e. it has to be a vector in which each element is similar to `(X⊗X, ((1,1), (1,2)))`, giving the observable operator and the `(register, slot)` indices for each observed subsystem. There is also a support for adding a third tuple element, a vector specifying the exact links to be drawn."))
        end
    end

    # ---- CORE UPDATE FUNCTION ----
    # this handles the majority of conversions from input data to graphics coordinates/metadata
    function update_plot(network)
        registers = network.registers
        registercoords = rn[:registercoords][]
        all_nodes = [
            register_rectangles, register_slots_coords,
            state_coords, state_links, lock_coords,
            register_slots_coords_backref, state_coords_backref,
            observables_coords, observables_links, observables_vals, observables_linkvals,
            # new
            tag_marker_coords, tag_marker_colors, tag_marker_shapes, tag_marker_labels,
            tag_marker_backref,
            mb_dot_coords, mb_dot_counts,
            qch_state_coords, qch_state_backref,
        ]
        for a in all_nodes
            empty!(a[])
        end

        # ---- register rectangles & slot positions ----
        for (iʳᵉᵍ, reg) in enumerate(registers)
            xʳᵉᵍ  = registercoords[iʳᵉᵍ][1]-0.3*rn[:scale][]
            yʳᵉᵍ  = registercoords[iʳᵉᵍ][2]-0.3*rn[:scale][]
            Δxʳᵉᵍ = 0.6*rn[:scale][]
            Δyʳᵉᵍ = (nsubsystems(reg)-0.4)*rn[:scale][]
            push!(register_rectangles[], Rect2f(xʳᵉᵍ, yʳᵉᵍ, Δxʳᵉᵍ, Δyʳᵉᵍ))
            for iˢˡᵒᵗ in 1:nsubsystems(reg)
                xˢˡᵒᵗ = registercoords[iʳᵉᵍ][1]
                yˢˡᵒᵗ = registercoords[iʳᵉᵍ][2]+(iˢˡᵒᵗ-1)*rn[:scale][]
                push!(register_slots_coords[], Point2f(xˢˡᵒᵗ, yˢˡᵒᵗ))
                push!(register_slots_coords_backref[], (reg, iʳᵉᵍ, iˢˡᵒᵗ))
                if reg.locks[iˢˡᵒᵗ].level >= 1
                    push!(lock_coords[], Point2f(xˢˡᵒᵗ, yˢˡᵒᵗ))
                end

                # ---- #66: Tag markers ----
                if rn[:tag_markers_enabled][] && length(QuantumSavory.peektags(reg[iˢˡᵒᵗ])) > 0
                    for tag in QuantumSavory.peektags(reg[iˢˡᵒᵗ])
                        style = tag_marker_style(tag)
                        # Position tag markers slightly to the right of the slot
                        x_tag = xˢˡᵒᵗ + 0.45*rn[:scale][] + 0.05*rn[:scale][] * length(tag_marker_coords[])
                        y_tag = yˢˡᵒᵗ
                        push!(tag_marker_coords[], Point2f(x_tag, y_tag))
                        push!(tag_marker_colors[], style.color)
                        push!(tag_marker_shapes[], style.shape)
                        push!(tag_marker_labels[], tag_short_label(tag))
                        push!(tag_marker_backref[], (iʳᵉᵍ, iˢˡᵒᵗ, tag))
                    end
                end
            end
        end

        # ---- #96: Message-buffer dot indicators ----
        if rn[:mb_markers_enabled][]
            for (iʳᵉᵍ, reg) in enumerate(registers)
                mb_count = if haskey(network.cbuffers, iʳᵉᵍ)
                    length(network.cbuffers[iʳᵉᵍ].buffer)
                else
                    0
                end
                x_mb = registercoords[iʳᵉᵍ][1] + 0.45*rn[:scale][]
                y_mb = registercoords[iʳᵉᵍ][2] + (nsubsystems(reg) - 0.2) * rn[:scale][]
                push!(mb_dot_coords[], Point2f(x_mb, y_mb))
                push!(mb_dot_counts[], mb_count)
            end
        end

        # ---- state subsystem markers and entanglement links ----
        states = unique(Iterators.flatten(((s for s in r.staterefs if !isnothing(s)) for r in registers)))
        for s in states
            for (iˢ, (reg, iˢˡᵒᵗ)) in enumerate(zip(s.registers, s.registerindices))
                isnothing(reg) && continue
                whichreg = findfirst(o->===(reg, o), registers)
                isnothing(whichreg) && continue
                xˢ = registercoords[whichreg][1]
                yˢ = registercoords[whichreg][2]+(iˢˡᵒᵗ-1)*rn[:scale][]
                pˢ = Point2f(xˢ, yˢ)
                push!(state_coords[], pˢ)
                push!(state_coords_backref[], (s, network[whichreg], whichreg, iˢˡᵒᵗ, iˢ))
                nsubsystems(s) == 1 || push!(state_links[], pˢ)
                iˢ == 1 || iˢ == nsubsystems(s) || push!(state_links[], pˢ)
            end
        end

        # ---- observable markers ----
        if !isnothing(rn[:observables][])
        for (O, rsidx, links) in rn[:observables][]
            val = real(observable(tuple((network[rs...] for rs in rsidx)...), O; something=NaN))
            for (iʳᵉᵍ, iˢˡᵒᵗ) in rsidx
                xˢ = registercoords[iʳᵉᵍ][1]
                yˢ = registercoords[iʳᵉᵍ][2]+(iˢˡᵒᵗ-1)*rn[:scale][]
                pˢ = Point2f(xˢ, yˢ)
                push!(observables_coords[], pˢ)
                push!(observables_vals[], val)
                push!(observables_backref[], (O, val))
            end
            for (iʳᵉᵍ, iˢˡᵒᵗ) in links
                xˢ = registercoords[iʳᵉᵍ][1]
                yˢ = registercoords[iʳᵉᵍ][2]+(iˢˡᵒᵗ-1)*rn[:scale][]
                pˢ = Point2f(xˢ, yˢ)
                push!(observables_links[], pˢ)
                push!(observables_linkvals[], val)
                push!(observables_links_backref[], (O, val))
            end
        end
        end

        # ---- #97: Quantum channel in-flight state positions ----
        if rn[:qch_markers_enabled][]
            g = network.graph
            for e in edges(g)
                src, dst = e.src, e.dst
                p_src = registercoords[src]
                p_dst = registercoords[dst]
                pair = src=>dst
                if haskey(network.qchannels, pair)
                    qc = network.qchannels[pair]
                    try
                        items = collect(qc.queue.store.items)
                        for (j, _) in enumerate(items)
                            t = j / (length(items) + 1)
                            mid = Point2f(
                                p_src[1] + (p_dst[1] - p_src[1]) * t,
                                p_src[2] + (p_dst[2] - p_src[2]) * t,
                            )
                            push!(qch_state_coords[], mid)
                            push!(qch_state_backref[], (src, dst, j))
                        end
                    catch
                        # queue may not be inspectable / empty
                    end
                end
            end
        end

        for a in all_nodes
            notify(a)
        end
    end

    # populate all graphical coordinates / metadata for the first time
    update_plot(networkobs[])

    # set up event modification notifications
    Makie.Observables.onany(update_plot, networkobs)
    Makie.Observables.onany([rn[:registercoords], rn[:observables]]) do _
        update_plot(networkobs)
    end

    # ---- RENDER ----

    # Register background rectangles
    register_polyplot = poly!(rn, register_rectangles, color=rn[:register_color],
        inspector_label = (self, i, p) -> "a register")
    register_polyplot.inspectable[] = false

    # Register slot squares
    register_slots_scatterplot = scatter!(
        rn, register_slots_coords,
        marker=rn[:slotmarker], markersize=rn[:slotsize][]*rn[:scale][], color=slotcolor_resolved,
        markerspace=:data,
        inspector_label = (self, i, p) -> get_slots_vis_string(networkobs, register_slots_coords_backref[], i))

    # Observable markers
    observables_scatterplot = scatter!(
        rn, observables_coords,
        marker=rn[:observables_marker], markersize=rn[:observables_markersize][]*rn[:scale][], markerspace=:data,
        color=observables_vals, colormap=rn[:colormap], colorrange=rn[:colorrange],
        inspector_label = (self, i, p) -> get_observables_vis_string(observables_backref[], i))
    observables_linesegments = linesegments!(
        rn, observables_links,
        linewidth=rn[:observables_linewidth][]*rn[:scale][],
        color=observables_linkvals, colormap=rn[:colormap], colorrange=rn[:colorrange],
        inspector_label = (self, i, p) -> get_observables_vis_string(observables_links_backref[], i))

    # State markers (black diamonds)
    state_scatterplot = scatter!(
        rn, state_coords,
        marker=rn[:state_marker], markersize=rn[:state_markersize][]*rn[:scale][], color=rn[:state_markercolor],
        markerspace=:data,
        inspector_label = (self, i, p) -> get_state_vis_string(state_coords_backref[], i))
    state_linesegmentsplot = linesegments!(rn, state_links, color=rn[:state_linecolor])
    state_linesegmentsplot.inspectable[] = false

    # Lock markers
    lock_scatterplot = scatter!(
        rn, lock_coords,
        marker=rn[:lock_marker], markersize=rn[:slotsize][]*rn[:scale][],
        markerspace=:data)
    lock_scatterplot.inspectable[] = false

    # ---- #66: Tag markers (colored shapes near tagged slots) ----
    tag_scatterplot = scatter!(
        rn, tag_marker_coords,
        marker=tag_marker_shapes,
        markersize=rn[:tag_markersize][]*rn[:scale][],
        color=tag_marker_colors,
        markerspace=:data,
        inspector_label = (self, i, p) -> get_tag_vis_string(tag_marker_backref[], i))
    # Optionally add short text labels next to tag markers
    if rn[:tag_label_enabled][]
        tag_textplot = text!(
            rn, tag_marker_coords,
            text=tag_marker_labels,
            textsize=rn[:tag_markersize][] * rn[:scale][] * 2,
            markerspace=:data,
            align=(:left, :center))
        tag_textplot.inspectable[] = false
    end

    # ---- #96: Message-buffer dot indicators ----
    mb_scatterplot = scatter!(
        rn, mb_dot_coords,
        marker=:circle,
        markersize=rn[:mb_markersize][]*rn[:scale][],
        color=:steelblue,
        markerspace=:data,
        inspector_label = (self, i, p) -> get_mb_vis_string(networkobs, mb_dot_coords[], mb_dot_counts[], i))

    # ---- #97: Quantum channel in-flight state markers ----
    qch_scatterplot = scatter!(
        rn, qch_state_coords,
        marker=:pentagon,
        markersize=rn[:qch_markersize][]*rn[:scale][],
        color=:coral,
        markerspace=:data,
        inspector_label = (self, i, p) -> get_qch_vis_string(networkobs, qch_state_backref[], i))

    _extras[:register_polyplot] = register_polyplot
    _extras[:register_slots_scatterplot] = register_slots_scatterplot
    _extras[:observables_scatterplot] = observables_scatterplot
    _extras[:observables_linesegmentsplot] = observables_linesegments
    _extras[:state_scatterplot] = state_scatterplot
    _extras[:state_linesegmentsplot] = state_linesegmentsplot
    _extras[:lock_scatterplot] = lock_scatterplot
    _extras[:tag_scatterplot] = tag_scatterplot
    _extras[:mb_scatterplot] = mb_scatterplot
    _extras[:qch_scatterplot] = qch_scatterplot
    rn[:_extras] = _extras
    rn
end

# ==================== Inspector label helpers ====================

function get_observables_vis_string(backrefs, i)
    o, val = backrefs[i]
    return "Observable ⟨$(o)⟩ = $(val)"
end

"""
Enhanced slot tooltip that includes tag information AND
message buffer status for the parent register (#66, #96).
"""
function get_slots_vis_string(networkobs, backrefs, i)
    network = networkobs[]
    register, registeridx, slot = backrefs[i]
    lines = String[]
    regname = compactstr(register)
    push!(lines, "Register $registeridx ($regname) | Slot $slot")
    # Tag info (#66 — hover level)
    tags = QuantumSavory.peektags(register[slot])
    if isempty(tags)
        push!(lines, "  no tags")
    else
        push!(lines, "  tags:")
        for t in tags
            push!(lines, "    • $(sprint(show, t; context=:compact=>true))")
        end
    end
    # Lock info
    if register.locks[slot].level >= 1
        push!(lines, "  🔒 locked")
    end
    # State info (if assigned)
    sr = stateof(register[slot])
    if !isnothing(sr)
        push!(lines, "  state info:")
        push!(lines, "    $(state_tooltip(sr))")
    end
    # Message buffer info (#96)
    if !isnothing(network) && haskey(network.cbuffers, registeridx)
        push!(lines, get_messagebuffer_string(network, registeridx))
    end
    return join(lines, "\n")
end

"""
Enhanced state tooltip with Bloch-vector components (#98)
and entanglement info.
"""
function get_state_vis_string(backrefs, i)
    state, register, registeridx, slot, subsystem = backrefs[i]
    lines = String[]
    push!(lines, "Subsystem $(subsystem) of a state of $(nsubsystems(state)) subsystems")
    push!(lines, "Register $registeridx ($(compactstr(register))) | Slot $slot")
    # Add Bloch / density-matrix tooltip (#98)
    tooltip = state_tooltip(state)
    for line in split(tooltip, "\n")
        push!(lines, "  $line")
    end
    # Tag info
    tags = [ti.tag for ti in values(register.tag_info) if ti.slot==slot]
    if !isempty(tags)
        push!(lines, "  tags:")
        for t in tags
            push!(lines, "    • $(sprint(show, t; context=:compact=>true))")
        end
    end
    # Message buffer info (#96)
    net = parent(register)
    if !isnothing(net)
        regidx = parentindex(register)
        push!(lines, get_messagebuffer_string(net, regidx))
    end
    return join(lines, "\n")
end

"""
Tooltip for tag markers (#66).
"""
function get_tag_vis_string(backrefs, i)
    regidx, slot, tag = backrefs[i]
    tag_str = sprint(show, tag; context=:compact=>true)
    descr = tag[1]
    descr_str = if descr isa Symbol
        String(descr)
    elseif descr isa DataType
        string(nameof(descr))
    else
        string(descr)
    end
    return "Tag: $tag_str\n  descriptor: $descr_str\n  on Register $regidx | Slot $slot"
end

"""
Tooltip for message-buffer dot indicators (#96).
"""
function get_mb_vis_string(networkobs, coords, counts, i)
    network = networkobs[]
    # Find which register this dot corresponds to (nearest-neighbor search)
    # We stored positions per register in the same order as registers
    regidx = i
    count = counts[i]
    if count == 0
        return "Node $regidx: message buffer empty"
    end
    lines = String[]
    push!(lines, "Node $regidx: message buffer ($count pending)")
    if haskey(network.cbuffers, regidx)
        mb = network.cbuffers[regidx]
        for (j, entry) in enumerate(mb.buffer)
            src = entry.src
            tag_str = sprint(show, entry.tag; context=:compact=>true)
            push!(lines, "  msg [$j] from $src: $tag_str")
        end
    end
    return join(lines, "\n")
end

"""
Tooltip for in-flight quantum channel states (#97).
"""
function get_qch_vis_string(networkobs, backrefs, i)
    network = networkobs[]
    src, dst, idx = backrefs[i]
    lines = String[]
    push!(lines, "Quantum channel $src → $dst")
    pair = src=>dst
    if haskey(network.qchannels, pair)
        qc = network.qchannels[pair]
        try
            items = collect(qc.queue.store.items)
            push!(lines, "  in-flight state $idx / $(length(items)) in queue")
            if 1 <= idx <= length(items)
                reg = items[idx]
                nsub = QuantumSavory.nsubsystems(reg)
                push!(lines, "  $nsub-subsystem state in transit")
                push!(lines, "  delay: $(qc.queue.delay) time units")
            end
        catch
            push!(lines, "  (queue inaccessible)")
        end
    else
        push!(lines, "  (channel not found)")
    end
    return join(lines, "\n")
end

# ==================== Interaction handler ====================

abstract type RegisterNetGraphHandler end
struct RNHandler <: RegisterNetGraphHandler
    rn
end

function Makie.process_interaction(handler::RNHandler, event::Makie.MouseEvent, axis)
    plot, index = Makie.pick(axis.scene)
    rn = handler.rn
    extras = rn[:_extras][]
    if plot===extras[:register_slots_scatterplot]
        register, registeridx, slot = extras[:register_slots_coords_backref][][index]
        try run(`clear`) catch end
        println("Register $registeridx | Slot $slot\n Details: $(register)")
    elseif plot===extras[:state_scatterplot]
        state, reg, registeridx, slot, subsystem = extras[:state_coords_backref][][index]
        try run(`clear`) catch end
        println("Subsystem stored in Register $(registeridx) | Slot $(slot)\n Subsystem $(subsystem) of $(state)")
    elseif plot===extras[:observables_scatterplot]
        o, val = extras[:observables_backref][][index]
        try run(`clear`) catch end
        println("Observable $(o) has value $(val)")
    elseif plot===extras[:tag_scatterplot]
        regidx, slot, tag = extras[:tag_marker_backref][][index]
        try run(`clear`) catch end
        println("Tag on Register $regidx | Slot $slot: $tag")
    elseif plot===extras[:mb_scatterplot]
        counts = extras[:mb_dot_counts][]
        regidx = index
        cnt = counts[index]
        println("Register $regidx | Message buffer: $cnt pending messages")
    elseif plot===extras[:qch_scatterplot]
        src, dst, idx = extras[:qch_state_backref][][index]
        println("Quantum channel $src→$dst | In-flight state #$idx")
    end
    false
end

# ==================== Public API ====================

"""
Draw the given registers on a given Makie axis or a subfigure.

It returns a tuple of (subfigure, axis, plot, observable).
The observable can be used to issue a `notify` call that updates
the plot with the current state of the network.
"""
function registernetplot_axis end

function registernetplot_axis(ax::Makie.AbstractAxis, registersobservable; infocli=true, datainspector=true, autolimits=false, kwargs...)
    registersobservable = registersobservable isa Observable ? registersobservable : Observable(registersobservable)
    p = registernetplot!(ax, registersobservable; kwargs...)
    ax.aspect = Makie.DataAspect()
    if hasmethod(Makie.hidedecorations!, Tuple{typeof(ax)})
        Makie.hidedecorations!(ax)
    end
    if hasmethod(Makie.hidespines!, Tuple{typeof(ax)})
        Makie.hidespines!(ax)
    end
    Makie.deregister_interaction!(ax, :rectanglezoom)
    if infocli
        rnh = RNHandler(p)
        Makie.register_interaction!(ax, :registernet, rnh)
    end
    if datainspector
        DataInspector(ax.parent)
    end
    if autolimits
        if hasmethod(Makie.autolimits!, Tuple{typeof(ax)})
            Makie.autolimits!(ax)
        end
    end
    # translating the plot so that it is in front of the background map
    Makie.translate!(p, 0, 0, 10)
    ax.parent, ax, p, registersobservable
end

# subfig::Union{GridPosition, GridSubposition} but maybe other as well, so leave it unspecified
function registernetplot_axis(subfig, registersobservable; infocli=true, datainspector=true, kwargs...)
    registernetplot_axis(Makie.Axis(subfig[1,1]), registersobservable; infocli, datainspector, kwargs...)
end

function registernetplot_axis(registersobservable; infocli=true, datainspector=true, kwargs...)
    fig = Figure()
    ax = Axis(fig[1, 1])
    registernetplot_axis(ax, registersobservable; infocli, datainspector, kwargs...)
end

##

showonplot(r::ConcurrentSim.Resource) = islocked(r)
showonplot(b::Bool) = b

"""
Draw the various resources and locks stored in the given meta-graph on a given Makie axis.

It returns a tuple of (subfigure, axis, plot, observable).
The observable can be used to issue a `notify` call that updates
the plot with the current state of the network.
"""
function resourceplot_axis(subfig, network, edgeresources, vertexresources; registercoords=nothing, title="")
    axis = Makie.Axis(subfig[1,1], title=title)
    networkobs = Makie.Observable(network)
    if isnothing(registercoords)
        # copied from registernetplot
        adj_matrix = adjacency_matrix(networkobs[].graph)
        registercoords = spring(adj_matrix, iterations=40, C=2*maximum(nsubsystems.(network.registers)))
    else
        registercoords = registercoords[]
    end
    baseplot = Makie.scatter!(axis,
            registercoords,
            color=:gray90,
            )
    for (i,vertexres) in enumerate(vertexresources)
        Makie.scatter!(axis,
            Makie.lift(x->Makie.Point2{Float64}[registercoords[j].+0.2*(i-1) for j in vertices(x) if showonplot(x[j,vertexres])],
                networkobs),
            color=Makie.Cycled(i),
            label="$(vertexres)"
            )
    end
    for (i,edgeres) in enumerate(edgeresources)
        Makie.linesegments!(axis,
            Makie.lift(x->Makie.Point2{Float64}[registercoords[n].+0.2*(i-1) for (;dst,src) in edges(x) for n in (dst,src) if showonplot(x[(dst,src),edgeres])],
                networkobs),
            color=Makie.Makie.Cycled(i),
            label="$(edgeres)"
            )
    end
    axis.aspect = Makie.DataAspect()
    Makie.Legend(subfig[2,1],axis,tellwidth = false, tellheight = true, orientation=:horizontal)
    Makie.hidedecorations!(axis)
    Makie.hidespines!(axis)
    Makie.autolimits!(axis)
    subfig, axis, baseplot, networkobs
end

##

function showmetadata(fig, ax, p, reg, slot)
    Makie.events(fig).mouseposition[] =
    tuple(Makie.shift_project(ax.scene, p.registercoords[][reg].+(0,slot-1))...);
end

##

include("state_explorer.jl")
include("show_state.jl")
include("show_protocol.jl")

end
