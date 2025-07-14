# News

## v0.5.1 - 2025-07-14

- Add `classical_delay` and `quantum_delay` as keyword arguments to the `RegisterNet` constructor to set a default global network edge latency.
- `onchange_tag` now permits a protocol to wait for any change to the tag metadata. Implemented thanks to the new `AsymmetricSemaphore`, a resource object that allows multiple processes to wait for an update.
- Plots of networks can now overlay real-world maps (see `generate_map`).
- A "state explorer" tool was added to the plotting submodule and as an interactive example, to heal visualize many of the states in StatesZoo.
- Additional filtering and decision capabilities in `EntanglerProt`.
- Fixes and additions to available background noise processes.
- Rebuilding the ZALM source from StatesZoo in a more reproducible fashion.
- Fixes and performance improvements to `observable`.
- New examples related to preparing GHZ states and MBQC-based purification.
- The switch protocol is now back to fully functional, thanks to an upstream fix in GraphsMatching.jl.

## v0.5.0 - 2024-10-16

- Develop `CutoffProt` to deal with deadlocks in a simulation
- Expand `SwapperProt` with `agelimit` to permit cutoff policies (with `CutoffProt`)
- Tutorial and interactive examples for entanglement distribution on a grid with local-only knowledge
- **(breaking)** `observable` now takes a default value as a kwarg, i.e., you need to make the substitution `observable(regs, obs, 0.0; time)` ↦ `observable(regs, obs; something=0.0, time)`
- Bump QuantumSymbolics and QuantumOpticsBase compat bound and bump julia compat to 1.10.
- Implement a simple switch protocol.
    - Simplify one of the switch protocols to avoid dependence on GraphsMatching.jl. which does not install well on non-linux systems. Do not rely on the default `SimpleSwitchDiscreteProt` for the time being.

## v0.4.2 - 2024-08-13

- Incorrect breaking release. It should have been 0.5 (see above).

## v0.4.1 - 2024-06-05

- Significant improvements to the performance of `query`.

## v0.4.0 - 2024-06-03

- Establishing `ProtocolZoo`, `CircuitZoo`, and `StateZoo`
- Establishing `Register`, `RegRef`, and `RegisterNet`
- Establishing the symbolic expression capabilities
- Establishing plotting and visualization capabilities

## older versions were not tracked
