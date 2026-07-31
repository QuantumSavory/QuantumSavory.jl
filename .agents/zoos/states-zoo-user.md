# StatesZoo for Users

Open this file when:

- you want a predefined quantum state family instead of deriving a source model from scratch;
- you want to initialize registers from a parameterized state model;
- you want to inspect a state family with the state explorer.

Do not use this file for:

- adding new `StatesZoo` families;
- explorer implementation details;
- backend-expression hooks.

Use `.agents/zoos/states-zoo-dev.md` for those.

## What StatesZoo Is For

- `StatesZoo` is a small catalog of parameterized state families for common networking resources.
- It is the right tool when you want a physically motivated surrogate state and a stable public constructor.
- It is not a general state-construction DSL.

## Current Families To Know

- `BarrettKokBellPair`
- `BarrettKokBellPairW`
- `DepolarizedBellPair`
- `QuantumSavory.StatesZoo.Genqo.GenqoUnheraldedSPDCBellPairW`
- `QuantumSavory.StatesZoo.Genqo.GenqoMultiplexedCascadedBellPairW`

## Normalized Versus Weighted States

- `BarrettKokBellPair` is normalized.
- Weighted families like `BarrettKokBellPairW` and the `Genqo...W` states use the trace as a success probability or rate-like weight.
- Do not silently treat weighted states as normalized density matrices.
- Use `state_family_schemas()` for the deterministic built-in catalog and
  `state_family_schema(StateType)` for ordered parameters and normalization
  style.
- Use `normalized_state_and_weight(state)` when a weighted family must become a
  normalized density matrix; keep the returned `weight` for the success model.

## Common Workflow

```julia
using QuantumSavory
using QuantumSavory.StatesZoo

reg = Register(2)
initialize!(reg[1:2], BarrettKokBellPair(0.9))
```

Explorer workflow:

```julia
using QuantumSavory.StatesZoo
stateexplorer(BarrettKokBellPair)
```

## Usage Guidance

- Use `StatesZoo` when you care about the output of a source model more than its microscopic derivation.
- Use the explorer to sweep parameters before baking one family into a larger simulation.
- Keep the weighted-versus-normalized distinction explicit in user-facing analysis code.
- Use `state_weight(state)` to inspect the absolute trace without duplicating
  trace evaluation policy.
- Treat `Genqo` families as optional-dependency models. They rely on Python tooling.
- Genqo constructors expose only backend-supported parameters. The current
  spin-density-matrix backends do not model detector excess noise.

## Good Docs And Examples To Open Next

- `docs/src/API_StatesZoo.md`
- `docs/src/zoos_as_building_blocks.md`
- `docs/src/tutorial/state_explorer.md`
- `examples/state_explorer/README.md`
- `examples/state_explorer/state_explorer.jl`

## Common Mistakes

- Using a weighted family and then interpreting its trace as if it were always 1.
- Re-implementing a source model inline when `StatesZoo` already has a suitable surrogate.
- Treating the explorer as a backend benchmark rather than a parameter-sweep tool for predefined families.
