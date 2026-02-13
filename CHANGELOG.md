# News

## v0.6.0 - unreleased

- **(breaking)** Some fields of EntanglerProt were renamed for consistency with other protocols. More such renaming is to be expected, for consistency's sake.
- **(breaking)** The `StatesZoo` now integrates with the `genqo` python package, to provide high accuracy models of the ZALM entanglement source. The previous implementation of the ZALM source was removed.
- **(breaking)** Renaming `wait(::MessageBuffer)` and `onchange_tag(::Register)` to `onchange`.
- Querying functions now also return the time at which a tag was tagged.
- `query_wait` now exists as a much simpler alternative to `onchange` followed by `query`.
- `GraphStateConstructor` protocol and related tooling for modeling of the iterative construction of a graph state out of Bell pairs.
- Protocol constructors moving to having constructors that do not require `sim` to be explicitly specified.
- Noise types now have default parameters, for ease of construction in examples. The default values generally correspond to near-zero noise (e.g. decoherence time of `1e9`).
- Protocols (subtypes of `AbstractProtocol` in the `ProtocolZoo`) now have rich `show` methods for the `image/png` and `text/html` MIME types
- Unexported function `permits_virtual_edge` to describe whether a protocol can run between two nodes that are not directly connected.
- Non-public functions `parent`, `parentindex`, `name`, `namestr`, `timestr`, `compactstr`,  `available_protocol_types`, `available_slot_types`, `available_background_types`, `constructor_metadata` for better introspection capabilities and cleaner printing.
- New interactive example: ring network entanglement distribution, demonstrating bidirectional entanglement flow, path redundancy, and standard ProtocolZoo integration on a cyclic topology (issue #138).

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
