# [Visualizations](@id Visualizations)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

We provide many visualization tools build on top of the [Makie.jl](https://docs.makie.org/stable/) framework for interactive visualizations.

The plotting functions generally return a tuple of (subfigure, axis, plot, observable).
The observable can be used to issue a `notify` call that updates the plot with the current state of the network without replotting from scratch.
This is particularly useful for live simulation visualizations.

## The quantum registers in the network

The [`registernetplot_axis`](@ref) function can be used to draw a given set of registers, together with the quantum states they contain. It also provides interactive tools for inspecting the content of the registers (by hovering or clicking on the corresponding register slot). Here we give an example where we define a network and then plot it:

```@example vis
using CairoMakie # or GLMakie for interactive plots
using QuantumSavory

# create a network of qubit registers
sizes = [2,3,2,5]
registers = Register[]
for s in sizes
    traits = [Qubit() for _ in 1:s]
    push!(registers, Register(traits))
end
network = RegisterNet(registers)

# add some states, entangle a few slots, perform some gates
initialize!(network[1,1])
initialize!(network[2,3], X₁)
initialize!((network[3,1],network[4,2]), X₁⊗Z₂)
apply!((network[2,3],network[3,1]), CNOT)

# create the plot
fig = Figure(resolution=(400,400))
_, _, _, obs = registernetplot_axis(fig[1,1],network)
fig
```

## The state of locks and various metadata in the network

The [`resourceplot_axis`](@ref) function can be used to draw all locks and resources stored in a meta-graph governing a discrete event simulation. Metadata stored at the vertices is plotted as colored or grayed out dots depending on their state. Metadata stored at the edges is shown as lines.

```@example vis
using Graphs
using SimJulia

sim = Simulation()

# add random metadata to vertices and edges of the network
for v in vertices(network)
    network[v,:bool] = rand(Bool)
    network[v,:resource] = Resource(sim,1)
    rand(Bool) && request(network[v,:resource])
end
for e in edges(network)
    network[e,:edge_bool] = true
    network[e,:another_bool] = rand(Bool)
end

# plot the resources and metadata

fig = Figure(resolution=(700,400))
resourceplot_axis(fig[1,1],network,
    [:edge_bool,:another_bool], # list of edge metadata to plot
    [:bool,:resource],          # list of vertex metadata
    registercoords=plt[:registercoords] # optionally, reuse register coordinates
)
fig
```

## Updating the plots

 You can call `notify` on the returned plot object to replot the state of the network after a change.