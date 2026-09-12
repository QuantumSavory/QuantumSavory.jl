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

# The slot tooltip also reports the node's pending message buffer (issue #96).
# The string builder is backend independent, so it is exercised here rather
# than in the GLMakie-only data-inspector testset.

let
    ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    net = RegisterNet([Register(2), Register(2), Register(2)])
    fig = Figure()
    _, _, plt, _ = registernetplot_axis(fig[1,1], net, infocli=false)
    backref = plt._extras[][:register_slots_coords_backref][]

    # An idle node says so explicitly rather than showing nothing.
    @test occursin("message buffer empty", ext.get_slots_vis_string(net, backref, 1))

    put!(channel(net, 1=>2), Tag(:hello))
    put!(channel(net, 3=>2), Tag(:world))
    run(get_time_tracker(net), 2.0)

    slot_of_node2 = findfirst(b -> b[2] == 2, backref)
    str = ext.get_slots_vis_string(net, backref, slot_of_node2)
    @test occursin("message buffer (2 pending)", str)
    @test occursin("hello", str)
    @test occursin("world", str)
    @test occursin("from 1", str)
    @test occursin("from 3", str)
    # The pre-existing register and slot header must survive.
    @test occursin("Register 2 | Slot", str)

    # A quiet node is unaffected by traffic elsewhere.
    slot_of_node3 = findfirst(b -> b[2] == 3, backref)
    @test occursin("message buffer empty", ext.get_slots_vis_string(net, backref, slot_of_node3))
end
