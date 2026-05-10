#using CairoMakie
#using GLMakie
using Graphs
using FileIO

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
tag!(net[4,1], Tag(:mytag, 1, 2))
tag!(net[3,1], Tag(:sometag, 10, 20))
initialize!(net[2,1], X1)
p = registernetplot_axis(fig[1,1], net, observables=[(X, ((1,2),)), (X⊗X⊗X, ((1,1),(2,2),(3,2)))], infocli=false)
display(fig)

##

fig = Figure()
net = RegisterNet([Register(2)])
tag!(net[1,1], :slot_tag, 7)
put!(messagebuffer(net[1]), :pending_message, 3)
_, ax, p, obs = registernetplot_axis(fig[1,1], net, infocli=false, datainspector=false)
qs_makie = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
empty_net = RegisterNet([Register(1)])
empty_slot_text = qs_makie.get_slots_vis_string([(empty_net[1], 1, 1)], 1)
@test occursin("not tagged", empty_slot_text)
@test occursin("message buffer empty", empty_slot_text)
@test qs_makie.messagebuffer_vis_string(Register(1)) == "message buffer unavailable"
slot_text = qs_makie.get_slots_vis_string([(net[1], 1, 1)], 1)
@test occursin("slot_tag", slot_text)
@test occursin("pending_message", slot_text)
@test occursin("message buffer", slot_text)
tag_text = qs_makie.get_tags_vis_string([(net[1], 1, 1, QuantumSavory.peektags(net[1,1]))], 1)
@test occursin("slot_tag", tag_text)
@test length(p._extras[][:tag_coords_backref][]) == 1
display(fig)
