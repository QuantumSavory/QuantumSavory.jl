# A Much Simpler Simulation of First Generation Quantum Repeater Chain

This `firstgenrepeater_v2` is a much simpler implementation compared to the `firstgenrepeater`. Behind the scenes the simulation is basically the same, but this `v2` uses much more convenient higher-level abstractions using ProtocolZoo, so the user needs to write much less code.

The `setup.jl` file implements all the shared base functionality (network setup, the custom purifier process).
Three example scripts then build on top of it:

1. **`1_entangler_example.jl`** — entanglement generation only, no swaps or purification;
2. **`2_swapper_example.jl`** — entanglement generation and swapping, presented as a full interactive web app with configuration sliders for both network and source parameters (no purification);
3. **`3_purifier_example.jl`** — entanglement generation, swapping, and purification, as a simple self-contained script.

## Example 1 — Entangler only

The simplest possible demonstration: `EntanglerProt` runs on every edge of the chain and continuously generates raw Bell pairs between neighboring nodes. No swapping or purification is performed.

```bash
julia --project=examples/firstgenrepeater_v2 examples/firstgenrepeater_v2/1_entangler_example.jl
```

This produces a short animation (`firstgenrepeater_v2-01.entangler.mp4`) showing the entanglement links building up over time.

## Example 2 — Swapper interactive web app

A full interactive demo that adds `SwapperProt` and `EntanglementTracker` on top of the entangler. Configuration sliders let you adjust both simulation parameters (chain length, register size, T₂, success probability, …) and the `GenqoMultiplexedCascadedBellPairW` entanglement source parameters in real time.

```bash
julia --project=examples/firstgenrepeater_v2 examples/firstgenrepeater_v2/2_swapper_example.jl
```

This launches a WGLMakie web app (default `http://127.0.0.1:8890`). Configure the repeater chain and Genqo source, then press **Run simulation** to watch entanglement propagate end-to-end. Purification is not included in this example.

## Example 3 — Purifier

Adds a purification step to example 2. All three protocol layers run together: `EntanglerProt` generates raw pairs on each link, `SwapperProt` extends entanglement across the chain, and a custom `purifier` process distills pairs between every node pair that shares two or more Bell pairs.

```bash
julia --project=examples/firstgenrepeater_v2 examples/firstgenrepeater_v2/3_purifier_example.jl
```

This records an animation (`firstgenrepeaterv2.purifier.mp4`) over 30 simulated time units showing entanglement generation, swapping, and purification all operating concurrently.

Documentation:

- [The "entangler" protocol `QuantumSavory.ProtocolZoo.EntanglerProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.EntanglerProt)
- [The "swapper" protocol `QuantumSavory.ProtocolZoo.SwapperProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.SwapperProt)
- [The "entanglement tracker" protocol which tracks classical metadata and communications `QuantumSavory.ProtocolZoo.EntanglementTracker`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.EntanglementTracker)
- [The "How To" doc page on setting up this simulation of a repeater chain](https://qs.quantumsavory.org/dev/howto/firstgenrepeater_v2/firstgenrepeater_v2)
- [The same simulation but done with very verbose low-level code](https://qs.quantumsavory.org/dev/howto/firstgenrepeater/firstgenrepeater)
