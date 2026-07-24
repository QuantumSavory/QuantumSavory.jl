# Circuits Catalog

- **Context need:** Reference
- **Open when:** Choosing a shipped immediate circuit or reviewing its destructive behavior.
- **Do not open when:** Adding a circuit, coordinating asynchronous protocols, or selecting state models.
- **Related specification IDs:** SYS-008, SUB-012, CMP-011
- **Review when:** CircuitZoo exports, callable behavior, measurement cleanup, or failure semantics change.

## Circuit families

CircuitZoo contains callable structs that execute immediately on register-slot
arguments. They are not SimJulia processes and do not wait for remote messages. Use the
human API for signatures; select by family:

- entanglement swapping: full `EntanglementSwap` with remote corrections and
  `LocalEntanglementSwap` for the local Bell measurement;
- purification: 2-to-1 and 3-to-1 complete/node forms plus stringent and expedient
  families;
- communication and graph construction: superdense `SDEncode`/`SDDecode` and `Fusion`.

Many circuits measure and trace out sacrificial inputs. Failure can also discard the
candidate output, depending on the algorithm. Callers must not assume input slots
remain occupied after invocation. Return values range from Boolean success to
measurement results; consult the concrete docstring rather than imposing one common
result type.

The shared executable surface is a callable method. `inputqubits` is useful but optional
in the current API tests, so absence does not by itself mean a circuit is invalid.
Code that needs capacity planning should check the selected type explicitly.

Advanced stringent/expedient node forms are not a settled correctness reference.
`StringentBodyNode` has current arity/return inconsistencies, and the documented
full-stringent failure reset semantics do not cleanly match all implementation paths.
Treat those behaviors as unresolved defects and run the focused purification tests
before reuse or documentation changes.

## Anchors

- **Source:** [`src/CircuitZoo/CircuitZoo.jl`](../../../src/CircuitZoo/CircuitZoo.jl) — all immediate circuit implementations and exports.
- **Docs:** [`docs/src/API_CircuitZoo.md`](../../../docs/src/API_CircuitZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public catalog and composition guidance.
- **Test:** [`test/general/circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`test/general/circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl), and [`test/general/circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl) — callable surface and family behavior.

## Unresolved questions

- What exact reset and return contract should stringent/expedient node failures have?
- Should `inputqubits` become mandatory for every public circuit?
