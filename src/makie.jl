using Graphs
using NetworkLayout
using Makie

@recipe(RegisterNetPlot) do scene
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

function Makie.plot!(rn::RegisterNetPlot{<:Tuple{RegisterNet}})
    networkobs = rn[1]
    registers = networkobs[].registers
    register_rectangles = Observable(Makie.Rect2{Float64}[])
    register_slots_coords = Observable(Makie.Point2f[])
    register_slots_coords_backref = Observable([])
    state_coords = Observable(Makie.Point2f[])
    state_coords_backref = Observable([])
    state_links = Observable(Makie.Point2f[])
    if haskey(rn, :registercoords) && !isnothing(rn[:registercoords][])
        registercoords = rn[:registercoords][]
    else
        adj_matrix = adjacency_matrix(networkobs[].graph)
        registercoords = spring(adj_matrix, iterations=40, C=1.5*maximum(nsubsystems.(registers)))
    end
    rn[:registercoords] = registercoords # TODO make sure it is an observable
    processes_coords = Observable(Makie.Point2f[])
    processes = get(rn, :processes, Observable([]))
    rn[:processes] = processes
    function update_plot(network)
        registers = network.registers
        all_nodes = [ # TODO it is rather wasteful to replot everything... do it smarter
            register_rectangles, register_slots_coords, register_slots_coords_backref,
            state_coords, state_coords_backref, state_links,
            processes_coords]
        for a in all_nodes
            empty!(a[])
        end
        for (i,r) in enumerate(registers) # TODO this should use the layout/connectivity system
            push!(register_rectangles[], Makie.Rect2(registercoords[i][1]-0.3,registercoords[i][2]+0.7-1,0.6,nsubsystems(r)-0.4))
            for j in 1:nsubsystems(r)
                push!(register_slots_coords[], Makie.Point2f(registercoords[i][1],registercoords[i][2]+j-1))
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
                push!(state_coords[], Makie.Point2f(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
                push!(state_coords_backref[],(s,si))
                if nsubsystems(s)==1
                    break
                end
                push!(state_links[], Makie.Point2f(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
                if !juststarted && si<nsubsystems(s)
                    push!(state_links[], state_links[][end])
                else
                    juststarted = false
                end
            end
        end
        for p in processes[]
            edgecoords = Makie.Point2f[]
            for (r,i) in p
                whichreg = findfirst(==(r),registers)
                if !isnothing(whichreg)
                    push!(edgecoords, Makie.Point2f(registercoords[whichreg][1], registercoords[whichreg][2]+i-1))
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
    Makie.Observables.onany(update_plot, networkobs)
    Makie.Observables.onany(update_plot, processes)
    update_plot(rn[1][])
    register_polyplot = poly!(rn,register_rectangles,color=:gray90)
    register_polyplot.inspectable[] = false
    register_slots_scatterplot = scatter!(rn,register_slots_coords,marker=:rect,color=:gray60,markersize=0.6,markerspace=Makie.SceneSpace)
    process_lineplot = linesegments!(rn,processes_coords,color=:pink,linewidth=20,markerspace=Makie.SceneSpace)
    state_scatterplot = scatter!(rn,state_coords,marker=:diamond,color=:black,markersize=0.4,markerspace=Makie.SceneSpace)
    state_lineplot = linesegments!(rn,state_links,color=:gray90)
    rn[:register_polyplot] = register_polyplot
    rn[:register_slots_scatterplot] = register_slots_scatterplot
    rn[:register_slots_coords_backref] = register_slots_coords_backref
    rn[:state_scatterplot] = state_scatterplot
    rn[:state_coords_backref] = state_coords_backref
    rn[:state_lineplot] = state_lineplot
    rn[:process_lineplot] = process_lineplot
    rn
end

abstract type RegisterNetGraphHandler end
struct RNHandler <: RegisterNetGraphHandler
    rn
end

function Makie.MakieLayout.process_interaction(handler::RNHandler, event::MouseEvent, axis)
    plot, index = mouse_selection(axis.scene)
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
    ax = Axis(subfig[1,1])
    p = registernetplot!(ax, registersobservable,
        registercoords=registercoords,
        )
    ax.aspect = DataAspect()
    hidedecorations!(ax)
    hidespines!(ax)
    deregister_interaction!(ax, :rectanglezoom)
    rnh = RNHandler(p)
    register_interaction!(ax, :registernet, rnh)
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
