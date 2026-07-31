# Circuits Catalog

- **Context need:** Reference
- **Open when:** Choosing a shipped immediate circuit or reviewing its destructive behavior.
- **Do not open when:** Adding a circuit, coordinating asynchronous protocols, or selecting state models.
- **Related specification IDs:** SYS-008, SYS-009, SUB-012, CMP-011
- **Review when:** CircuitZoo exports, callable behavior, measurement cleanup, or failure semantics change.

## Circuit families

CircuitZoo contains callable structs that execute immediately on register-slot
arguments. They are not ConcurrentSim processes and do not wait for remote messages.
Use the human API for signatures; select by family:

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

The exported callable types are supported entries. Helper types such as
`StringentHead` and `StringentBody` are unexported internals even though the current API
test discovers every direct `AbstractCircuit` subtype.

The supported public feature-introspection function is `inputqubits`, part of the
documented `AbstractCircuit` interface in source. It is unexported, unmarked, absent
from generated prose, optional in the API test, missing for `SDEncode` and `SDDecode`,
and inaccurate for two Stringent body helpers. The public feature/arity surface
required by SUB-012 and CMP-011 therefore remains incomplete.

Current purification limitations are concrete:

- `StringentBody.inputqubits` reports 6/8 qubits for expedient/stringent mode, but its
  callable also consumes two purified inputs, for totals of 8/10.
- `StringentBodyNode.inputqubits` reports 3/4 but its callable consumes 4/5 including
  the purified input.
- `StringentBodyNode` computes `alfa`, `beta`, optional `gamma`, and `delta`, then
  returns only scalar `alfa`; `PurifyStringentNode` later splats that scalar.
- `PurifyStringent` and `PurifyExpedient` docstrings promise reset on failure, while
  their implementations return a Boolean without tracing out the retained pair.
- `Purify3to1` accepts equal `leaveout1`/`leaveout2`, while correctness loops skip
  equality and therefore do not establish that case.

`SDEncode` and `SDDecode` also omit `inputqubits`. Treat these as visible implementation
gaps, not reusable contracts, and run `general/circuitzoo_purification` or the matching
family test before reuse or documentation changes.

## Anchors

- **Source:** [`src/CircuitZoo/CircuitZoo.jl`](../../../src/CircuitZoo/CircuitZoo.jl) — all immediate circuit implementations and exports.
- **Docs:** [`docs/src/API_CircuitZoo.md`](../../../docs/src/API_CircuitZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public catalog and composition guidance.
- **Test:** [`test/general/circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`test/general/circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl), and [`test/general/circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl) — callable surface and family behavior.

## Known gaps

- Public feature and arity introspection is not marked or enforced consistently.
- Stringent/expedient arity, return-shape, and documented reset behavior disagree with
  implementation.
- The equal-`leaveout` `Purify3to1` case lacks discriminating evidence.
