# Add a Circuit

- **Context need:** Task playbook
- **Open when:** Implementing or revising an immediate callable CircuitZoo operation.
- **Do not open when:** Merely selecting an existing circuit or writing a resumable network protocol.
- **Related specification IDs:** SYS-008, SYS-009, SUB-012, CMP-011
- **Review when:** The callable circuit interface, register operation semantics, or CircuitZoo API tests change.

## Add the circuit

1. Define a small `AbstractCircuit` subtype in `src/CircuitZoo/CircuitZoo.jl` or a
   clearly included sibling file. Keep configuration in fields and execution in one
   callable method. Current API tests expect exactly one applicable call implementation
   per public circuit type.
2. State slot order, required occupancy, supported representations, return value, and
   destructive effects in the docstring. A measurement commonly traces out its input;
   failure may also reset the candidate state. These are caller-visible contracts.
3. Compose the shared register primitives (`apply!`, `project_traceout!`,
   `observable`, and `traceout!`) rather than reaching into state references. Remember
   that multi-step mutation is not transactional; design cleanup for every failure
   prefix.
4. Implement `inputqubits` when a stable count helps callers. It is optional under the
   current surface test, so add it deliberately rather than returning a misleading
   count for variable-arity behavior.
5. Export the public type and place it in the human CircuitZoo API. Keep the long
   formula, example, and signature catalog in human docs rather than reproducing it in
   agent context.
6. Add a focused test for ideal success, detectable failure, undetected-error behavior
   where relevant, destroyed slots, return shape, and at least one unsupported or
   invalid input. Extend `circuitzoo_api_tests.jl` so the callable surface remains
   discoverable.
7. Run the family tests and the general shard. Immediate circuits can still affect
   protocol tests because ProtocolZoo composes them.

Do not use the current stringent/expedient node paths as unquestioned templates:
`StringentBodyNode` has arity/return inconsistencies and full-stringent failure cleanup
is disputed between code and documentation.

## Anchors

- **Source:** [`src/CircuitZoo/CircuitZoo.jl`](../../../src/CircuitZoo/CircuitZoo.jl) — interface and all existing patterns.
- **Docs:** [`docs/src/API_CircuitZoo.md`](../../../docs/src/API_CircuitZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public placement and composition.
- **Test:** [`test/general/circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`test/general/circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), and [`test/general/circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl) — interface, success, and cleanup patterns.

## Unresolved questions

- Should circuit execution gain a shared validation or rollback layer?
- Should variable-arity circuits receive a replacement for `inputqubits`?
