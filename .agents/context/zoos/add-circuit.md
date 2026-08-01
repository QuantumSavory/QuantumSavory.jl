# Add a Circuit

- **Context need:** Task playbook
- **Open when:** Implementing or revising an immediate callable CircuitZoo operation.
- **Do not open when:** Merely selecting an existing circuit or writing a resumable network protocol.
- **Review when:** The callable circuit interface, register operation semantics, or CircuitZoo API tests change.

## Add the circuit

1. Define a small `AbstractCircuit` subtype with configuration in fields and execution
   in one callable method. Repository entries live in `src/CircuitZoo/CircuitZoo.jl` or
   an included sibling file; external libraries can implement the same documented
   callable convention. The current API test constructs every direct subtype,
   including internal helpers, with `T()` and expects exactly one callable
   implementation.
2. State slot order, required occupancy, supported representations, modeled result
   values, and destructive effects in the docstring. A measurement commonly traces out
   its input; an ordinary failure result may also reset the candidate state.
3. Compose the shared register primitives (`apply!`, `project_traceout!`,
   `observable`, and `traceout!`) rather than reaching into state references. Implement
   cleanup for modeled Boolean/measurement failure branches. A thrown exception may
   leave partial mutation and ends the run; do not build rollback solely for it.
4. Implement the supported public `inputqubits` feature/arity interface for every
   circuit. It remains unexported and optional in the current surface test, so do not
   extend those marking and coverage gaps. Count fixed purified inputs as well as
   sacrificed varargs. For a callable with non-slot arguments such as `SDEncode`'s
   message, distinguish data from slots.
5. Export or declare the public type, and place it in the human CircuitZoo API with a
   user-oriented example. Keep formulas and signature catalogs in human docs.
6. Add a focused test for ideal success, detectable failure, undetected-error behavior
   where relevant, destroyed slots, return shape, and at least one unsupported or
   invalid input. Extend `circuitzoo_api_tests.jl` so the callable surface remains
   discoverable.
7. Run the family tests and the general shard. Immediate circuits can still affect
   protocol tests because ProtocolZoo composes them.

Do not use stringent/expedient or equal-leaveout 3-to-1 paths as templates without
checking the exact [cataloged limitations](circuits-catalog.md).

## Anchors

- **Source:** [`src/CircuitZoo/CircuitZoo.jl`](../../../src/CircuitZoo/CircuitZoo.jl) — interface and all existing patterns.
- **Docs:** [`docs/src/API_CircuitZoo.md`](../../../docs/src/API_CircuitZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public placement and composition.
- **Test:** [`test/general/circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`test/general/circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), and [`test/general/circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl) — interface, success, and cleanup patterns.

## Current gap

`AbstractCircuit` and `inputqubits` are supported extension interfaces but still need
generated prose plus `public` declarations. `inputqubits` also needs complete fixed- and
variable-arity coverage.
