# [Manual](@id manual)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

## Getting Started

### Installation

To use QuantumSavory, make sure you have Julia version 1.10 installed. You can download and install Julia from [the official Julia website](https://julialang.org/downloads/).

Once Julia is setup, QuantumSavory can be installed with the following command in your in your Julia REPL:
```bash
$ julia
julia> ]
pkg> add QuantumSavory
```

#### Optional Dependencies

There are optional packages that you need to install to use the full plotting feature.
- **Makie**: For plotting of registers and processes.
- **GeoMakie**: Enables plotting on a real-world map as a background.

## Basic Demo

Here’s a simple example to demonstrate how you can set up a simulation to generate a set of registers with qubit slots. For more advanced examples and detailed guide, see[How-To Guides](@ref) and [Tutorials](@ref) sections.

```
using QuantumSavory

# This is a network of three registers, each with 2, 3, and 4 Qubit slots.
net = RegisterNet([Register(2), Register(3), Register(4)])

# initialize slots and entangle them
initialize!(net[1,1])
initialize!(net[2,3], X₁)
initialize!((net[3,1],net[4,2]), X₁⊗Z₂)

# apply CNOT gate
apply!((net[2,3],net[3,1]), CNOT)
```

If you have `Makie` and `GeoMakie` installed, you can plot the above network:
```
using GLMakie
GLMakie.activate!()

# generate background map
map_axis = generate_map()

fig, ax, plt, obs = registernetplot_axis(map_axis, net, registercoords=[Point2f(-71, 42), Point2f(-111, 34), Point2f(-122, 37)])
fig
```
