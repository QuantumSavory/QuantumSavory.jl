using QuantumSavory
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
