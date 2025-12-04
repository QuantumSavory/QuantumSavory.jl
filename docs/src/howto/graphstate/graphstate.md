# [Graph State Examples](@id Graph-State-Examples)

This page demonstrates the `graphstate` example in the `examples/graphstate` folder.
Graph states are a convenient way to describe multipartite entanglement with a simple graph representation.

The `examples/graphstate` contains a small set of scripts that build and visualize graph states,
compute simple observables, and demonstrate how `QuantumSavory.jl` represents graph-based quantum networks.

## What this example shows

- How to construct a `RegisterNet` representing the nodes of a graph state.
- How to initialize qubits into graph-state stabilizer states.
- How to compute simple observables (stabilizers, correlators) and plot the network.

## Quick start

Open the example file in `examples/graphstate/` and run it with the package environment:

```bash
# from the repository root
julia --project=. examples/graphstate/graph_preparer.jl
```

If you prefer to run the code from the REPL, run `julia --project=.`, then:

```julia
using QuantumSavory
include("examples/graphstate/graph_preparer.jl")
```

## Suggested reading and related resources

- See the `firstgenrepeater` how-to for a longer example of building and simulating network primitives: [firstgenrepeater](@ref howto/firstgenrepeater/firstgenrepeater.md).
- API docs for the main data structures: [`Register`](@ref) and [`RegisterNet`](@ref).

The example source is in `examples/graphstate` in this repository.