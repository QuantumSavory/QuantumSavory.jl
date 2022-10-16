using Graphs
using NetworkLayout
import Makie
import Makie: Theme, Figure, Axis, @recipe

export registernetplot, registernetplot_axis, resourceplot_axis

@recipe(RegisterNetPlot, regnet) do scene
    Theme()
end

function Makie.plot!(rn::RegisterNetPlot{<:Tuple{RegisterNet}})
    networkobs = rn[1]
    registers = networkobs[].registers
    register_rectangles = Makie.Observable(Makie.Rect2{Float64}[])
    register_slots_coords = Makie.Observable(Makie.Point2{Float64}[])
    register_slots_coords_backref = Makie.Observable([])
    state_coords = Makie.Observable(Makie.Point2{Float64}[])
    state_coords_backref = Makie.Observable([])
    state_links = Makie.Observable(Makie.Point2{Float64}[])
    if haskey(rn, :registercoords) && !isnothing(rn[:registercoords][])
        registercoords = rn[:registercoords][]
    else
        adj_matrix = adjacency_matrix(networkobs[].graph)
        registercoords = spring(adj_matrix, iterations=40, C=2*maximum(nsubsystems.(registers)))
    end
    rn[:registercoords] = registercoords # TODO make sure it is an observable
    function update_plot(network)
        registers = network.registers
        all_nodes = [ # TODO it is rather wasteful to replot everything... do it smarter
            register_rectangles, register_slots_coords, register_slots_coords_backref,
            state_coords, state_coords_backref, state_links,
        ]
        for a in all_nodes
            empty!(a[])
        end
        for (i,r) in enumerate(registers) # TODO this should use the layout/connectivity system
            push!(register_rectangles[], Makie.Rect2(registercoords[i][1]-0.3,registercoords[i][2]+0.7-1,0.6,nsubsystems(r)-0.4))
            for j in 1:nsubsystems(r)
                push!(register_slots_coords[], Makie.Point2{Float64}(registercoords[i][1],registercoords[i][2]+j-1))
                push!(register_slots_coords_backref[], (r,j))
            end
        end
        states = unique(vcat([[s for s in r.staterefs if !isnothing(s)] for r in registers]...))
        for s in states
            juststarted = true
            for (si,(r,i)) in enumerate(zip(s.registers,s.registerindices))
                isnothing(r) && continue
                whichreg = findfirst(o->===(r,o),registers)
                #isnothing(whichreg) && continue
                push!(state_coords[], Makie.Point2{Float64}(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
                push!(state_coords_backref[],(s,si))
                if nsubsystems(s)==1
                    break
                end
                push!(state_links[], Makie.Point2{Float64}(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
                if !juststarted && si<nsubsystems(s)
                    push!(state_links[], state_links[][end])
                else
                    juststarted = false
                end
            end
        end
        for a in all_nodes
            notify(a)
        end
    end
    Makie.Observables.onany(update_plot, networkobs)
    update_plot(rn[1][])
    register_polyplot = Makie.poly!(rn,register_rectangles,color=:gray90)
    register_polyplot.inspectable[] = false
    register_slots_scatterplot = Makie.scatter!(rn,register_slots_coords,marker=:rect,color=:gray60,markersize=0.6,markerspace=:data)
    state_scatterplot = Makie.scatter!(rn,state_coords,marker=:diamond,color=:black,markersize=0.4,markerspace=:data)
    state_lineplot = Makie.linesegments!(rn,state_links,color=:gray90)
    rn[:register_polyplot] = register_polyplot
    rn[:register_slots_scatterplot] = register_slots_scatterplot
    rn[:register_slots_coords_backref] = register_slots_coords_backref
    rn[:state_scatterplot] = state_scatterplot
    rn[:state_coords_backref] = state_coords_backref
    rn[:state_lineplot] = state_lineplot
    rn
end

abstract type RegisterNetGraphHandler end
struct RNHandler <: RegisterNetGraphHandler
    rn
end

function Makie.process_interaction(handler::RNHandler, event::Makie.MouseEvent, axis)
    plot, index = Makie.mouse_selection(axis.scene)
    rn = handler.rn
    if plot===rn[:register_slots_scatterplot][]
        register, slot = rn[:register_slots_coords_backref][][index]
        run(`clear`)
        println("Slot $(slot) of $(register)")
    elseif plot===rn[:state_scatterplot][]
        state, subsystem = rn[:state_coords_backref][][index]
        run(`clear`)
        println("Subsystem $(subsystem) of $(state)")
    end
    false
end

##

"""Draw the given registers on a given Makie axis."""
function registernetplot_axis(subfig, registersobservable; registercoords=nothing)
    ax = Makie.Axis(subfig)
    p = registernetplot!(ax, registersobservable,
        registercoords=registercoords,
        )
    ax.aspect = Makie.DataAspect()
    Makie.hidedecorations!(ax)
    Makie.hidespines!(ax)
    Makie.deregister_interaction!(ax, :rectanglezoom)
    rnh = RNHandler(p)
    Makie.register_interaction!(ax, :registernet, rnh)
    subfig, ax, p
end

##

showonplot(r::SimJulia.Resource) = !isfree(r)
showonplot(b::Bool) = b

"""Draw the various resources and locks stored in the given meta-graph on a given Makie axis."""
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
    subfig, axis, baseplot
end
