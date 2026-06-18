# Memory Cutoff Tradeoff

This example explores a common repeater-network design tradeoff: how long a
node should retain entangled memories before discarding them.

Short retention times free memory quickly and avoid swapping stale qubits.
Long retention times can increase the number of end-to-end pairs delivered,
but those pairs may spend longer under background noise before they are
consumed. The example sweeps retention times in a small chain and reports
delivery counts plus the mean `ZZ` and `XX` stabilizer values measured by an
`EntanglementConsumer`.

The source code is in the [`examples/memorycutoff`](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/memorycutoff) folder.

The reusable setup uses:

- [`EntanglerProt`](@ref) on every physical link,
- [`SwapperProt`](@ref) at intermediate nodes,
- [`EntanglementTracker`](@ref) for classical update and delete messages,
- [`CutoffProt`](@ref) at every node, and
- [`EntanglementConsumer`](@ref) between the end users.

Run the deterministic sweep with:

```julia
include("examples/memorycutoff/1_cutoff_sweep.jl")
```

Run the interactive WGLMakie dashboard with:

```julia
include("examples/memorycutoff/2_wglmakie_interactive.jl")
```
