# A Much Simpler Simulation of First Generation Quantum Repeater Chain

This `firstgenrepeater_v2` is much simpler implementation compared to the `firstgenrepeater`. Behind the scenes the simulation is basically the same, but this `v2` uses much more convenient higher-level abstractions, so the user needs to write much less code.

## Running the interactive swapper demo

To explore the repeater chain with configurable Genqo sources, run:

```bash
julia --project=examples/firstgenrepeater_v2 examples/firstgenrepeater_v2/2_swapper_example.jl
```

This launches a WGLMakie web app (default `http://127.0.0.1:8890`) that lets you adjust both simulation parameters and the `GenqoMultiplexedCascadedBellPairW` state used by the entangler.

TODO: This example does not include the final purification step.

Documentation:

- [The "entangler" protocol `QuantumSavory.ProtocolZoo.EntanglerProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.EntanglerProt)
- [The "swapper" protocol `QuantumSavory.ProtocolZoo.SwapperProt`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.SwapperProt)
- [The "entanglement tracker" protocol which tracks classical metadata and communications `QuantumSavory.ProtocolZoo.EntanglementTracker`](https://qs.quantumsavory.org/dev/API_ProtocolZoo/#QuantumSavory.ProtocolZoo.EntanglementTracker)
- [The "How To" doc page on setting up this simulation of a repeater chain](https://qs.quantumsavory.org/dev/howto/firstgenrepeater_v2/firstgenrepeater_v2)
- [The same simulation but done with very verbose low-level code](https://qs.quantumsavory.org/dev/howto/firstgenrepeater/firstgenrepeater)