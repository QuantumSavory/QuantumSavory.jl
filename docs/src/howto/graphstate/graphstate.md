# [Graph State Examples](@id Graph-State-Examples)

This page demonstrates the `graphstate` example in the `examples/graphstate` folder.
Graph states are a convenient way to describe multipartite entanglement with a simple graph representation.

The `examples/graphstate` contains a small set of scripts that build and visualize graph states (via a GraphMakie plot of the register network), compute simple observables, and demonstrate how `QuantumSavory.jl` represents graph-based quantum networks.

## What this example shows

- How to construct a `RegisterNet` representing the nodes of a graph state.
- How to initialize qubits into graph-state stabilizer states.
- How to compute simple observables (stabilizers, correlators) and plot the network.

## Quick start

Open the example file in `examples/graphstate/` and run it with the package environment:

```bash
# from the repository root
julia examples/graphstate/graph_preparer.jl
```

If you prefer to run the code from the REPL, run `julia`, then:

```julia
using QuantumSavory
include("examples/graphstate/graph_preparer.jl")
```

## Suggested reading and related resources

- API docs for the main data structures: `Register` (@ref QuantumSavory.Register) and `RegisterNet` (@ref QuantumSavory.RegisterNet).


The example source is in `examples/graphstate` in this repository.