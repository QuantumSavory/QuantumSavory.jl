#using CairoMakie
#using GLMakie
using Graphs
using FileIO
using QuantumSavory.ProtocolZoo: EntanglementCounterpart

if !isdefined(@__MODULE__, :TagPickScene)
    @eval struct TagPickScene
        plot
        index::Int
    end
    @eval Makie.pick(scene::TagPickScene) = (scene.plot, scene.index)
end

##

regnet = RegisterNet([Register(2), Register(3)])
fig = Figure()
ax = Makie.Axis(fig[1, 1])
p = registernetplot!(ax, regnet)
ax.aspect = Makie.DataAspect()
Makie.hidedecorations!(ax)
Makie.hidespines!(ax)
fig

##

regnet = RegisterNet([Register(2), Register(3)])

##

fig = Figure()
ax = Axis(fig[1,1])
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), registercoords=rand(2,1))
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), registercoords=rand(1,2))
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), registercoords=[1.1,1.1])
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), registercoords=[[1.1,1.1]])
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), registercoords=[(1.1,1.1)])
registernetplot!(ax, RegisterNet([Register(2)]), registercoords=[Point2f(1,1)])
display(fig)

##

fig = Figure()
ax = Axis(fig[1,1])
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), observables=[("pretend I am an operator",)])
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), observables=[(X, 1)])
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), observables=[(X, (1,1))])
registernetplot!(ax, RegisterNet([Register(2)]), observables=[(X, ((1,1),))])
net = RegisterNet([Register(2)])
initialize!(net[1,1], X1)
registernetplot!(ax, net, observables=[(X, ((1,1),), [(1,1),(1,1)])])
@test_throws ArgumentError registernetplot!(ax, RegisterNet([Register(2)]), observables=[(X, ((1,1),), ((1,1),))]) # TODO consider permitting this
display(fig)

##

fig = Figure()
ax = Axis(fig[1,1])
net = RegisterNet([Register(2),Register(2),Register(2), Register(1)])
initialize!((net[1,1], net[2,2], net[3,2]), X1⊗X1⊗X1)
initialize!((net[1,2], net[3,1]), X1⊗X1)
initialize!(net[2,1], X1)
p = registernetplot!(ax, net, observables=[(X, ((1,2),)), (X⊗X⊗X, ((1,1),(2,2),(3,2)))])
display(fig)

##

fig = Figure()
registernetplot_axis(fig[1,1], RegisterNet([Register(1), Register(2)]),
                  slotcolor=:red)
display(fig)

##

fig = Figure()
registernetplot_axis(fig[1,1], RegisterNet([Register(1), Register(2)]),
                  slotcolor=(:red,0.1))
display(fig)

##

fig = Figure()
registernetplot_axis(fig[1,1], RegisterNet([Register(1), Register(2)]),
                  slotcolor=[(:red,0.1), :blue, :gray10])
display(fig)

##

fig = Figure()
registernetplot_axis(fig[1,1], RegisterNet([Register(1), Register(2)]),
                  slotcolor=[[(:red,0.1)], [:blue, :gray10]])
display(fig)

##

fig = Figure()
net = RegisterNet([Register(2),Register(2),Register(2), Register(1)])
initialize!((net[1,1], net[2,2], net[3,2]), X1⊗X1⊗X1)
initialize!((net[1,2], net[3,1]), X1⊗X1)
QuantumSavory.showonplot(::Val{:hoveronly}, tag::QuantumSavory.Tag) = false
tag!(net[1,1], Tag(:hoveronly))
tag!(net[4,1], Tag(:mytag, 1, 2))
tag!(net[3,1], Tag(:sometag, 10, 20))
initialize!(net[2,1], X1)
_, _, p, _ = registernetplot_axis(fig[1,1], net, observables=[(X, ((1,2),)), (X⊗X⊗X, ((1,1),(2,2),(3,2)))], infocli=false)
makie_ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
tag_backrefs = p._extras[][:tag_coords_backref][]
@test first.(tag_backrefs) == [Tag(:sometag, 10, 20), Tag(:mytag, 1, 2)]
@test Tag(:hoveronly) ∉ first.(tag_backrefs)
@test length(p._extras[][:tag_coords][]) == 2
@test makie_ext.tag_visual_key(Tag(:sometag, 10, 20)) == Val(:sometag)
@test makie_ext.tag_visual_key(Tag(EntanglementCounterpart, 1, 2)) == EntanglementCounterpart
@test makie_ext.tag_visual_key(Tag(Tag(:nested), 1)) == QuantumSavory.Tag
@test QuantumSavory.showonplot(Tag(:sometag, 10, 20))
@test QuantumSavory.showonplot(Tag(EntanglementCounterpart, 1, 2))
@test !QuantumSavory.showonplot(Tag(:hoveronly))
@test makie_ext.tag_marker_offset(Tag(Tag(:nested), 1), 2, 3, 2.0) == Makie.Point2f(0.66, 0.0)
@test occursin("Tag on Register 3 | Slot 1", makie_ext.get_tag_vis_string(tag_backrefs, 1))
@test occursin("sometag", makie_ext.get_tag_vis_string(tag_backrefs, 1))
tag_pick_event = Makie.MouseEvent(Makie.MouseEventTypes.leftclick, 0.0, Makie.Point2d(0, 0), Makie.Point2f(0, 0), 0.0, Makie.Point2d(0, 0), Makie.Point2f(0, 0))
tag_interaction_result = redirect_stdout(devnull) do
    Makie.process_interaction(makie_ext.RNHandler(p), tag_pick_event, (; scene=TagPickScene(p._extras[][:tag_scatterplot], 1)))
end
@test !tag_interaction_result
slot_tooltip = makie_ext.get_slots_vis_string([(net[1], 1, 1)], 1)
@test occursin("hoveronly", slot_tooltip)
display(fig)

net = RegisterNet([Register(1)])
fig = Figure()
_, _, p, netobs = registernetplot_axis(fig[1,1], net, infocli=false)
@test isempty(p._extras[][:tag_coords][])
tag!(net[1,1], Tag(:late_tag))
notify(netobs)
@test first.(p._extras[][:tag_coords_backref][]) == [Tag(:late_tag)]
