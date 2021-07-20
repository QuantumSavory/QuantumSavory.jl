using Graphs
using MetaGraphs
using NetworkLayout
using Makie

@recipe(RegistersGraph) do scene
    Theme(
    Axis = (
        backgroundcolor = :gray90,
        leftspinevisible = false,
        rightspinevisible = false,
        bottomspinevisible = false,
        topspinevisible = false,
        xgridcolor = :white,
        ygridcolor = :white,
    )
    )
end

function Makie.plot!(rg::RegistersGraph{<:Tuple{AbstractVector{Register}}})
    registers = rg[1]
    register_rectangles = Observable(Makie.Rect2D{Float64}[])
    register_slots_coords = Observable(Makie.Point2f0[])
    register_slots_coords_backref = Observable([])
    state_coords = Observable(Makie.Point2f0[])
    state_coords_backref = Observable([])
    state_links = Observable(Makie.Point2f0[])
    if haskey(rg, :registercoords) && !isnothing(rg[:registercoords][])
        registercoords = rg[:registercoords][]
    elseif haskey(rg, :graph) && !isnothing(rg[:graph][])
        adj_matrix = adjacency_matrix(rg[:graph][])
        registercoords = spring(adj_matrix, iterations=40, C=1.5*maximum(nsubsystems.(registers[])))
    else
        registercoords = [(i,0) for i in 1:length(registers[])]
    end
    rg[:registercoords] = registercoords # TODO make sure it is an observable
    processes_coords = Observable(Makie.Point2f0[])
    processes = get(rg, :processes, Observable([]))
    rg[:processes] = processes
    function update_plot(registers)
        all_nodes = [ # TODO it is rather wasteful to replot everything... do it smarter
            register_rectangles, register_slots_coords, register_slots_coords_backref,
            state_coords, state_coords_backref, state_links,
            processes_coords]
        for a in all_nodes
            empty!(a[])
        end
        for (i,r) in enumerate(registers) # TODO this should use the layout/connectivity system
            push!(register_rectangles[], Makie.Rect2D(registercoords[i][1]-0.3,registercoords[i][2]+0.7-1,0.6,nsubsystems(r)-0.4))
            for j in 1:nsubsystems(r)
                push!(register_slots_coords[], Makie.Point2f0(registercoords[i][1],registercoords[i][2]+j-1))
                push!(register_slots_coords_backref[], (r,j))
            end
        end
        states = unique(vcat([[s for s in r.staterefs if !isnothing(s)] for r in registers]...))
        for s in states
            for (si,(r,i)) in enumerate(zip(s.registers,s.registerindices))
                whichreg = findfirst(==(r),registers)
                #isnothing(whichreg) && continue
                push!(state_coords[], Makie.Point2f0(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
                push!(state_coords_backref[],(s,si))
                if nsubsystems(s)==1
                    break
                end
                push!(state_links[], Makie.Point2f0(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
                if 1<si<nsubsystems(s)
                    push!(state_links[], state_links[][end])
                end
            end
        end
        for p in processes[]
            edgecoords = Makie.Point2f0[]
            for (r,i) in p
                whichreg = findfirst(==(r),registers)
                if !isnothing(whichreg)
                    push!(edgecoords, Makie.Point2f0(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
                end
            end
            center = sum(edgecoords)/length(edgecoords)
            for p in edgecoords
                push!(processes_coords[], center)
                push!(processes_coords[], p)
            end
        end
        for a in all_nodes
            notify(a)
        end
    end
    Makie.Observables.onany(update_plot, registers)
    Makie.Observables.onany(update_plot, processes)
    update_plot(registers[])
    register_polyplot = poly!(rg,register_rectangles,color=:gray90)
    register_polyplot.inspectable[] = false
    register_slots_scatterplot = scatter!(rg,register_slots_coords,marker=:rect,color=:gray60,markersize=0.6,markerspace=Makie.SceneSpace)
    process_lineplot = linesegments!(rg,processes_coords,color=:pink,linewidth=20,markerspace=Makie.SceneSpace)
    state_scatterplot = scatter!(rg,state_coords,marker=:diamond,color=:black,markersize=0.4,markerspace=Makie.SceneSpace)
    state_lineplot = linesegments!(rg,state_links,color=:gray90)
    rg[:register_polyplot] = register_polyplot
    rg[:register_slots_scatterplot] = register_slots_scatterplot
    rg[:register_slots_coords_backref] = register_slots_coords_backref
    rg[:state_scatterplot] = state_scatterplot
    rg[:state_coords_backref] = state_coords_backref
    rg[:state_lineplot] = state_lineplot
    rg[:process_lineplot] = process_lineplot
    rg
end

abstract type RegistersGraphHandler end
struct RGHandler <: RegistersGraphHandler
    rg
end

function Makie.MakieLayout.process_interaction(handler::RGHandler, event::MouseEvent, axis)
    plot, index = mouse_selection(axis.scene)
    rg = handler.rg
    if plot===rg[:register_slots_scatterplot][]
        register, slot = rg[:register_slots_coords_backref][][index]
        run(`clear`)
        println("Slot $(slot) of $(register)")
    elseif plot===rg[:state_scatterplot][]
        state, subsystem = rg[:state_coords_backref][][index]
        run(`clear`)
        println("Subsystem $(subsystem) of $(state)")
    end
    false
end

##

"""Draw the given registers on a given Makie axis."""
function registersgraph_axis(subfig, registersobservable; graph=nothing, registercoords=nothing)
    ax = Axis(subfig[1,1])
    p = registersgraph!(ax, registersobservable,
        registercoords=registercoords,
        graph=graph,
        )
    ax.aspect = DataAspect()
    hidedecorations!(ax)
    hidespines!(ax)
    deregister_interaction!(ax, :rectanglezoom)
    rgh = RGHandler(p)
    register_interaction!(ax, :registergraph, rgh)
    subfig, ax, p
end

##

showonplot(r::SimJulia.Resource) = !isfree(r)
showonplot(b::Bool) = b

"""Draw the various resources and locks stored in the given meta-graph on a given Makie axis."""
function resourceplot_axis(subfig, graphobservable, edgeresources, vertexresources, registercoords; title="")
    axis = Axis(subfig[1,1], title=title)
    baseplot = scatter!(axis, # just to set coordinates
            registercoords[],
            color=:gray90,
            #markerspace=Makie.SceneSpace,
            )
    for (i,vertexres) in enumerate(vertexresources)
        scatter!(axis,
            lift(x->Point2{Float64}[registercoords[][j] for j in vertices(x) if showonplot(get_prop(x,i,vertexres))],
                    graphobservable),
            color=Cycled(i),
            #markerspace=Makie.SceneSpace,
            label="$(vertexres)"
            )
    end
    for (i,edgeres) in enumerate(edgeresources)
        linesegments!(axis,
            lift(x->Point2{Float64}[registercoords[][n] for (;dst,src) in edges(x) for n in (dst,src) if showonplot(get_prop(x,dst,src,edgeres))],
                 graphobservable),
            color=Cycled(i),
            #markerspace=Makie.SceneSpace,
            label="$(edgeres)"
            )
    end
    axis.aspect = DataAspect()
    Legend(subfig[2,1],axis,tellwidth = false, tellheight = true, orientation=:horizontal)
    hidedecorations!(axis)
    hidespines!(axis)
    autolimits!(axis)
    subfig, axis, baseplot
end
