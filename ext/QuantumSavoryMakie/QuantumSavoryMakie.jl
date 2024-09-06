module QuantumSavoryMakie

using QuantumSavory
using Graphs
using NetworkLayout
import ConcurrentSim
import Makie
import Makie: Theme, Figure, Axis,
    @recipe, lift, Observable,
    Point2, Point2f, Rect2f,
    scatter!, poly!, linesegments!,
    DataInspector
import QuantumSavory: registernetplot, registernetplot!, registernetplot_axis, resourceplot_axis, showonplot, showmetadata

##

@recipe(RegisterNetPlot, regnet) do scene
    Theme(
        colormap = :Spectral,
        colorrange = (-1., 1.),
        register_color = :gray90,
        slotcolor = :gray60,
        slotmarker = :rect,
        slotsize = 0.8,
        observables_marker = :circle,
        observables_markersize = 0.55,
        observables_linewidth = 5,
        state_markersize = 0.4,
        state_marker = :diamond,
        state_markercolor = :black,
        state_linecolor = :gray90,
        lock_marker = '⚿',  # TODO plot the state of the locks
        # The registercoords and observables arguments are not considered "theme" configuration options
    )
end

function Makie.plot!(rn::RegisterNetPlot{<:Tuple{RegisterNet}})
    networkobs = rn[1]
    registers = networkobs[].registers

    register_rectangles = Observable(Rect2f[])     # Makie rectangles that will be plotted for each register
    register_slots_coords = Observable(Point2f[])  # Makie marker locations that will be plotted for each register slot
    state_coords = Observable(Point2f[])           # Makie marker locations for each slot that contains a state subsystem
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
    rn[:register_backref] = register_backref
    rn[:register_slots_coords_backref] = register_slots_coords_backref
    rn[:state_coords_backref] = state_coords_backref
    rn[:observables_backref] = observables_backref
    rn[:observables_links_backref] = observables_links_backref

    # Optional arguments
    ## registercoords -- updates handled explicitly by an `onany` call below
    if haskey(rn, :registercoords) && !isnothing(rn[:registercoords][])
        registercoordsobs = rn[:registercoords]
        registercoords = registercoordsobs[]
        registercoords isa Vector{<:Point2} || throw(ArgumentError("While plotting a network layout an incorrect argument was given: `registercoords` has to be of type `Vector{<:Point2}`. You can leave it empty to autogenerate a register layout. You can generate it manually or with packages like `NetworkLayout`."))
        rn[:registercoords] = registercoordsobs
    else
        adj_matrix = adjacency_matrix(networkobs[].graph)
        registercoords = spring(adj_matrix, iterations=40, C=2*maximum(nsubsystems.(registers)))
        rn[:registercoords] = Observable(registercoords)
    end
    ## slotcolor -- updates handled implicitly (used only in a single `scatter` call)
    if haskey(rn, :slotcolor) && !isnothing(rn[:slotcolor][])
        slotcolorobs = rn[:slotcolor]
        if slotcolorobs[] isa Vector{<:Vector} # A vector of vector of colors (i.e. a vector of colors per register)
            rn[:slotcolor] = lift(x->reduce(vcat, x), slotcolorobs) # Turn it into a vector of colors
        end
    end
    ## observables -- updates handled explicitly by an `onany` call below
    if haskey(rn, :observables) && !isnothing(rn[:observables][])
        observablesobs = rn[:observables]
        if observablesobs[] isa Vector{<:Tuple{Any,Tuple{Vararg{Tuple{Int,Int}}}}}
            observables = Tuple{Any, Tuple{Vararg{Tuple{Int,Int}}}, Vector{Tuple{Int,Int}}}[]
            for (O, rsidx) in observablesobs[]
                links = Tuple{Int,Int}[]
                if length(rsidx)>1
                    for (i, (iʳᵉᵍ, iˢˡᵒᵗ)) in enumerate(rsidx)
                        push!(links, (iʳᵉᵍ, iˢˡᵒᵗ))
                        i == 1 || i == length(rsidx) || push!(links, (iʳᵉᵍ, iˢˡᵒᵗ))
                    end
                end
                push!(observables, (O, rsidx, links))
            end
            rn[:observables] = Observable(observables)
        elseif observablesobs[] isa Vector{<:Tuple{Any,Tuple{Vararg{Tuple{Int,Int}}},Vector{Tuple{Int,Int}}}}
            # the expected most general format
        else
            throw(ArgumentError("While plotting a network layout an incorrect argument was given: `observables` has to be of type `Vector{<:Tuple{Any, Tuple{...}}}`, i.e. it has to be a vector in which each element is similar to `(X⊗X, ((1,1), (1,2)))`, giving the observable operator and the `(register, slot)` indices for each observed subsystem. There is also a support for adding a third tuple element, a vector specifying the exact links to be drawn."))
        end
    else
        rn[:observables] = nothing
    end

    # this handles the majority of conversions from input data to graphics coordinates/metadata
    function update_plot(network)
        registers = network.registers
        registercoords = rn[:registercoords][]
        all_nodes = [ # TODO it is rather wasteful to replot everything... do it smarter
            register_rectangles, register_slots_coords,
            state_coords, state_links,
            register_slots_coords_backref, state_coords_backref,
            observables_coords, observables_links, observables_vals, observables_linkvals
        ]
        for a in all_nodes # using a naive `lift` would allocate, so instead we just empty each array and refill it; can still be done more elegantly with lift and preallocation
            empty!(a[])
        end

        # the location of the registers and the slots inside of the registers
        for (iʳᵉᵍ,reg) in enumerate(registers)
            xʳᵉᵍ  = registercoords[iʳᵉᵍ][1]-0.3
            yʳᵉᵍ  = registercoords[iʳᵉᵍ][2]+0.7-1
            Δxʳᵉᵍ = 0.6
            Δyʳᵉᵍ = nsubsystems(reg)-0.4
            push!(register_rectangles[], Rect2f(xʳᵉᵍ, yʳᵉᵍ, Δxʳᵉᵍ, Δyʳᵉᵍ))
            for iˢˡᵒᵗ in 1:nsubsystems(reg)
                xˢˡᵒᵗ = registercoords[iʳᵉᵍ][1]
                yˢˡᵒᵗ = registercoords[iʳᵉᵍ][2]+iˢˡᵒᵗ-1
                push!(register_slots_coords[], Point2f(xˢˡᵒᵗ,yˢˡᵒᵗ))
                push!(register_slots_coords_backref[], (reg,iʳᵉᵍ,iˢˡᵒᵗ))
            end
        end

        # the locations of the state subsystem markers and the lines connecting them (denoting belonging to the same system)
        states = unique(Iterators.flatten(((s for s in r.staterefs if !isnothing(s)) for r in registers)))
        for s in states
            for (iˢ,(reg,iˢˡᵒᵗ)) in enumerate(zip(s.registers,s.registerindices))
                isnothing(reg) && continue # TODO -- the state does not belong to a register... this should be a warning
                whichreg = findfirst(o->===(reg,o),registers) # TODO -- some form of caching or a backref would be valuable to significantly optimize this (skip the need for a O(n) search)
                isnothing(whichreg) && continue # TODO -- the state does not belong to a register in the network... maybe it is in a temporary message buffer register?
                xˢ = registercoords[whichreg][1]
                yˢ = registercoords[whichreg][2]+iˢˡᵒᵗ-1
                pˢ = Point2f(xˢ, yˢ)
                push!(state_coords[], pˢ)
                push!(state_coords_backref[], (s, network[whichreg], whichreg, iˢˡᵒᵗ, iˢ))
                nsubsystems(s) == 1 || push!(state_links[], pˢ)
                iˢ == 1 || iˢ == nsubsystems(s) || push!(state_links[], pˢ)
            end
        end

        ## the colors and locations for various observables
        if !isnothing(rn[:observables][])
        for (O, rsidx, links) in rn[:observables][]
            val = real(observable(tuple((network[rs...] for rs in rsidx)...), O; something=NaN))
            # TODO issue a warning if val has (percentage-wise) significant imaginary component (here, for plotting, when we implicitly are taking the real part)
            for (iʳᵉᵍ, iˢˡᵒᵗ) in rsidx
                xˢ = registercoords[iʳᵉᵍ][1]
                yˢ = registercoords[iʳᵉᵍ][2]+iˢˡᵒᵗ-1
                pˢ = Point2f(xˢ, yˢ)
                push!(observables_coords[], pˢ)
                push!(observables_vals[], val)
                push!(observables_backref[], (O, val))
            end
            for (iʳᵉᵍ, iˢˡᵒᵗ) in links
                xˢ = registercoords[iʳᵉᵍ][1]
                yˢ = registercoords[iʳᵉᵍ][2]+iˢˡᵒᵗ-1
                pˢ = Point2f(xˢ, yˢ)
                push!(observables_links[], pˢ)
                push!(observables_linkvals[], val)
                push!(observables_links_backref[], (O, val))
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

    # generate the actual graphics
    register_polyplot = poly!(rn, register_rectangles, color=rn[:register_color],
        inspector_label = (self, i, p) -> "a register")
    register_polyplot.inspectable[] = false # TODO this `Poly` plot does not seem to be properly inspectable
    register_slots_scatterplot = scatter!(
        rn, register_slots_coords,
        marker=rn[:slotmarker], markersize=rn[:slotsize], color=rn[:slotcolor],
        markerspace=:data,
        inspector_label = (self, i, p) -> get_slots_vis_string(register_slots_coords_backref[],i))
    observables_scatterplot = scatter!(
        rn, observables_coords,
        marker=rn[:observables_marker], markersize=rn[:observables_markersize], markerspace=:data,
        color=observables_vals, colormap=rn[:colormap], colorrange=rn[:colorrange],
        inspector_label = (self, i, p) -> get_observables_vis_string(observables_backref[],i))
    observables_linesegments = linesegments!(
        rn, observables_links,
        linewidth=rn[:observables_linewidth],
        color=observables_linkvals, colormap=rn[:colormap], colorrange=rn[:colorrange],
        inspector_label = (self, i, p) -> get_observables_vis_string(observables_links_backref[],i))
    state_scatterplot = scatter!(
        rn, state_coords,
        marker=rn[:state_marker], markersize=rn[:state_markersize], color=rn[:state_markercolor],
        markerspace=:data,
        inspector_label = (self, i, p) -> get_state_vis_string(state_coords_backref[],i))
    state_linesegmentsplot = linesegments!(rn, state_links, color=rn[:state_linecolor])
    state_linesegmentsplot.inspectable[] = false

    # TODO all of these should be wrapped into their own types in order to simplify DataInspector and process_interaction
    rn[:register_polyplot] = register_polyplot
    rn[:register_slots_scatterplot] = register_slots_scatterplot
    rn[:observables_scatterplot] = observables_scatterplot
    rn[:observables_linesegmentsplot] = observables_linesegments
    rn[:state_scatterplot] = state_scatterplot
    rn[:state_linesegmentsplot] = state_linesegmentsplot
    rn
end

function get_observables_vis_string(backrefs, i)
    o, val = backrefs[i]
    return "Observable ⟨$(o)⟩ = $(val)"
end

function get_slots_vis_string(backrefs, i)
    register, registeridx, slot = backrefs[i]
    tags = QuantumSavory.peektags(register[slot])
    tags_str = if isempty(tags)
        "not tagged"
    else
        "tagged with:\n"*join((" • $(t)" for t in tags), "\n")
    end
    return "Register $(registeridx) | Slot $(slot)\n $(tags_str)"
end

function get_state_vis_string(backrefs, i)
    state, register, registeridx, slot, subsystem = backrefs[i]
    tags = [ti.tag for ti in values(register.tag_info) if ti.slot==slot]
    tags_str = if isempty(tags)
        "not tagged"
    else
        "tagged with:\n"*join((" • $(t)" for t in tags), "\n")
    end
    return "Subsystem $(subsystem) of a state of $(nsubsystems(state)) subsystems, stored in\nRegister $(registeridx) | Slot $(slot)\n $(tags_str)"
end

abstract type RegisterNetGraphHandler end
struct RNHandler <: RegisterNetGraphHandler
    rn
end

function Makie.process_interaction(handler::RNHandler, event::Makie.MouseEvent, axis)
    plot, index = Makie.pick(axis.scene)
    rn = handler.rn
    #if plot===rn[:register_polyplot][]             # TODO this does not work because poly seems to be much too basic for `pick` to provide a useful reference
    #    register = rn[:register_backref][][index]
    #    run(`clear`)
    #    println("$(register)")
    #else
    if plot===rn[:register_slots_scatterplot][]
        register, registeridx, slot = rn[:register_slots_coords_backref][][index]
        try run(`clear`) catch end
        println("Register $registeridx | Slot $(slot)\n Details: $(register)")
    elseif plot===rn[:state_scatterplot][]
        state, reg, registeridx, slot, subsystem = rn[:state_coords_backref][][index]
        try run(`clear`) catch end
        println("Subsystem stored in Register $(registeridx) | Slot $(slot)\n Subsystem $(subsystem) of $(state)")
    elseif plot===rn[:observables_scatterplot][]
        o, val = rn[:observables_backref][][index]
        try run(`clear`) catch end
        println("Observable $(o) has value $(val)")
    end
    false
end

##

"""Draw the given registers on a given Makie axis.

It returns a tuple of (subfigure, axis, plot, observable).
The observable can be used to issue a `notify` call that updates
the plot with the current state of the network."""
function registernetplot_axis(subfig, registersobservable; infocli=true, datainspector=true, kwargs...)
    ax = Makie.Axis(subfig)
    p = registernetplot!(ax, registersobservable; kwargs...)
    ax.aspect = Makie.DataAspect()
    Makie.hidedecorations!(ax)
    Makie.hidespines!(ax)
    Makie.deregister_interaction!(ax, :rectanglezoom)
    if infocli
        rnh = RNHandler(p)
        Makie.register_interaction!(ax, :registernet, rnh)
    end
    if datainspector
        DataInspector(subfig)
    end
    Makie.autolimits!(ax)
    subfig, ax, p, p[1]
end

##

showonplot(r::ConcurrentSim.Resource) = islocked(r)
showonplot(b::Bool) = b

"""Draw the various resources and locks stored in the given meta-graph on a given Makie axis.

It returns a tuple of (subfigure, axis, plot, observable).
The observable can be used to issue a `notify` call that updates
the plot with the current state of the network."""
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
    baseplot = Makie.scatter!(axis, # just to set coordinates
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

end
