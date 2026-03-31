# CircuitZoo for Contributors

Open this file when:

- adding or reviewing a circuit in `CircuitZoo`;
- changing circuit calling conventions or argument validation;
- debugging destructive circuit behavior or measurement-return semantics.

Do not use this file for basic selection of a public circuit.
Use `.agents/zoos/circuit-zoo-user.md` for that.

## Extension Pattern

- Subtype `AbstractCircuit`.
- Define one callable method for the circuit object.
- Define `inputqubits(::YourCircuit)` when meaningful.
- Keep implementations on public register operations such as:
  - `initialize!`
  - `apply!`
  - `observable`
  - `project_traceout!`
  - `traceout!`

## Semantics To Preserve

- Full circuits operate on the whole local-distributed routine and often return success/failure.
- `...Node` variants are intentionally partial and usually return local measurement results.
- `EntanglementSwap` applies remote corrections; `LocalEntanglementSwap` only measures locally.
- Purification circuits intentionally consume sacrificial qubits and may discard the kept pair on failure.
- `Fusion` works at the register-and-slot level and may initialize storage slots if needed.

## Review Checks

- Confirm constructor validation for symbolic parameters like `:X`, `:Y`, `:Z`.
- Check argument ordering carefully, especially in purification circuits.
- Preserve destructive behavior expectations in tests.
- Keep circuits backend-agnostic. They should not reach into register internals.
- `test/general/circuitzoo_api_tests.jl` assumes one callable method per circuit instance; update tests if that contract changes intentionally.

## Source Files To Read

- `src/CircuitZoo/CircuitZoo.jl`

## Tests To Anchor Behavior

- `test/general/circuitzoo_api_tests.jl`
- `test/general/circuitzoo_ent_swap_tests.jl`
- `test/general/circuitzoo_purification_tests.jl`
- `test/general/circuitzoo_fusion_tests.jl`
- `test/general/circuitzoo_superdense_tests.jl`
- `test/general/setup_circuitzoo_purification.jl`

## Public Docs And Paper To Cross-Check

- `docs/src/API_CircuitZoo.md`
- `docs/src/zoos_as_building_blocks.md`
- `docs/src/discreteeventsimulator.md`
- `docs/src/howto/firstgenrepeater/firstgenrepeater.md`
- `../writeup/zoos.tex`
- `../writeup/Overview.tex`
- `../writeup/quantumsavory.tex`
