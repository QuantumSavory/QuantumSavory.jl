# News

## v0.6.0 - 2024-09-13

- Simplify one of the switch protocols to avoid dependence on GraphMatching.jl which does not install well on non-linux systems. Do not rely on the default `SimpleSwitchDiscreteProt` for the time being.

## v0.5.0 - 2024-09-05

- Develop `CutoffProt` to deal with deadlocks in a simulation
- Expand `SwapperProt` with `agelimit` to permit cutoff policies (with `CutoffProt`)
- Tutorial and interactive examples for entanglement distribution on a grid with local-only knowledge
- **(breaking)** `observable` now takes a default value as a kwarg, i.e., you need to make the substitution `observable(regs, obs, 0.0; time)` ↦ `observable(regs, obs; something=0.0, time)`
- Bump QuantumSymbolics and QuantumOpticsBase compat bound and bump julia compat to 1.10.

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