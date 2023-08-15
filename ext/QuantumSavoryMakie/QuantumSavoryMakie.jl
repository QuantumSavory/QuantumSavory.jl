module QuantumSavoryMakie

using QuantumSavory
using Graphs
using NetworkLayout
import ConcurrentSim
import Makie
import Makie: Theme, Figure, Axis, @recipe
import QuantumSavory: registernetplot, registernetplot_axis, resourceplot_axis, showonplot

@recipe(RegisterNetPlot, regnet) do scene
    Theme()
end

const bell = StabilizerState("XX ZZ")
function Makie.plot!(rn::RegisterNetPlot{<:Tuple{RegisterNet}}) # TODO plot the state of the locks
    networkobs = rn[1]
    registers = networkobs[].registers
    register_rectangles = Makie.Observable(Makie.Rect2{Float64}[])
    register_slots_coords = Makie.Observable(Makie.Point2{Float64}[])
    register_slots_coords_backref = Makie.Observable([])
    state_coords = Makie.Observable(Makie.Point2{Float64}[])
    state_coords_backref = Makie.Observable([])
    state_links = Makie.Observable(Makie.Point2{Float64}[])
    clrs = Makie.Observable(Float32[])
    regs = Makie.Observable([])
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
            clrs, regs
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
                push!(regs[], (whichreg, i))

                if !juststarted && si<nsubsystems(s)
                    push!(state_links[], state_links[][end])
                    push!(regs[], regs[][end])

                else
                    juststarted = false
                end
            end
        end

        for i in 1:2:length(state_links[])
            fid = real(observable([registers[regs[][i][1]][regs[][i][2]], registers[regs[][i+1][1]][regs[][i+1][2]]], projector(bell)))
            push!(clrs[], fid)
            push!(clrs[], fid)
        end
        # println("OBSERVABLES [[[[[[[")

        # println(rn)
        # println(state_links[])
        # println(clrs[])
        # println(LinRange(1, 5, length(state_links[])))

        # println("]]]]]]")

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
    state_lineplot = Makie.linesegments!(rn,state_links,color=clrs, colormap=:viridis, colorrange = (0, 1))
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

"""Draw the given registers on a given Makie axis.

It returns a tuple of (subfigure, axis, plot, observable).
The observable can be used to issue a `notify` call that updates
the plot with the current state of the network."""
function registernetplot_axis(subfig, registersobservable; registercoords=nothing, interactions=false)
    ax = Makie.Axis(subfig)
    p = registernetplot!(ax, registersobservable,
        registercoords=registercoords,
        )
    ax.aspect = Makie.DataAspect()
    Makie.hidedecorations!(ax)
    Makie.hidespines!(ax)
    Makie.deregister_interaction!(ax, :rectanglezoom)
    if interactions
        rnh = RNHandler(p)
        Makie.register_interaction!(ax, :registernet, rnh)
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

end
