# Heralded Entanglement Percolation

This example explores a standard question in quantum-network design: when
nearest-neighbor Bell-pair generation is probabilistic, how often does a lattice
contain a usable entangled path between two distant users?

The model uses an `n` by `n` repeater lattice. Alice is the upper-left node and
Bob is the lower-right node. During one heralding round, each nearest-neighbor
edge independently succeeds with probability `p`. If the successful elementary
links connect Alice and Bob, the example selects the shortest available path and
estimates the final Bell-pair fidelity after entanglement swapping along that
path.

The fidelity estimate uses a Werner-like visibility model:

```julia
visibility = (4F - 1) / 3
F_path = (1 + 3 * visibility^hops * swap_visibility^(hops - 1)) / 4
```

This keeps the example lightweight while still showing the central trade-off:
higher link success makes end-to-end connectivity more likely, but longer paths
compound elementary-link and swapping imperfections.

## Run

From the repository root:

```sh
julia --project=examples examples/percolation_lattice/setup.jl
julia --project=examples examples/percolation_lattice/1_interactive_visualization.jl
```

For the browser version:

```sh
julia --project=examples examples/percolation_lattice/2_wglmakie_interactive.jl
```

By default the browser app serves on `http://127.0.0.1:8894`.

## Files

- `setup.jl`: deterministic lattice generation, heralded-link sampling, path
  finding, and ensemble summaries.
- `interactive_dashboard.jl`: backend-neutral Makie dashboard construction.
- `1_interactive_visualization.jl`: GLMakie desktop entry point.
- `2_wglmakie_interactive.jl`: WGLMakie browser entry point.
