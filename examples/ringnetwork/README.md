# Ring Network Entanglement Distribution

An interactive simulation of entanglement distribution over a **ring topology**.

## Overview

A ring of N quantum nodes (default N=8) where Alice (node 1) and Bob (node N/2+1,
diametrically opposite) want to share entangled pairs. Unlike a linear repeater chain,
the ring provides **two disjoint paths** between Alice and Bob:

- **Clockwise path**: Alice → 2 → 3 → ... → Bob
- **Counterclockwise path**: Alice → N → N-1 → ... → Bob

Both paths operate simultaneously, providing redundancy and increased throughput
compared to a single chain of the same hop count.

## Running the examples

Interactive GLMakie visualization:

```julia
include("examples/ringnetwork/1_interactive_visualization.jl")
```

Web-based WGLMakie visualization:

```julia
include("examples/ringnetwork/2_wglmakie_interactive.jl")
```

## What to look for

- **Bidirectional flow**: entanglement links appear on both halves of the ring
  simultaneously, delivering pairs to Alice and Bob from either direction.
- **Decoherence effects**: increase the qubit retention time slider to see how longer
  memory lifetimes improve throughput and fidelity.
- **Success probability**: even small increases in entanglement generation probability
  have a large impact on delivery rate due to the multiplicative nature of multi-hop
  entanglement.

## Protocols used

| Protocol | Role |
|----------|------|
| `EntanglerProt` | Generates Bell pairs on each edge of the ring |
| `SwapperProt` | Performs entanglement swaps at intermediate nodes, directed toward Alice or Bob |
| `EntanglementTracker` | Tracks and updates entanglement metadata after swaps |
| `EntanglementConsumer` | Measures and logs delivered pairs between Alice and Bob |
| `CutoffProt` | Frees memory slots whose qubits have decohered past the retention time |
