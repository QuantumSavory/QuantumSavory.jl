# Backend Extension

- **Context need:** Task playbook
- **Open when:** Implementing or repairing a representation backend or its symbolic lowering.
- **Do not open when:** Only comparing existing support or changing a backend-independent protocol.
- **Related specification IDs:** STK-004, SYS-009, SUB-010
- **Review when:** Backend extension seams, representation traits, or the shared operation interface changes.

## Add or repair a backend

1. Define the representation and state types at the existing representation seam.
   Decide explicitly which symbolic state families, operations, observables, backgrounds,
   and destructive operations are in scope. Do not claim whole-backend support from one
   successful lowering method.
2. Implement initialization and representation selection deliberately:
   `newstate(trait, repr)`, `express_nolookup(symbolic, repr)`, `default_repr(native)`,
   and `consistent_representation(...)` where mixed slot preferences need a policy.
   Use `_wrap_state_for_slots(state, reprs)` when stored native state needs a structural
   wrapper such as `MCKet`.
3. Supply `nsubsystems`, `subsystemcompose`, and native `apply!` for the state and
   operation combinations actually supported. Add `observable`, `project_traceout!`,
   backend partial `traceout!`, and `uptotime!` only for their documented capabilities;
   absence should remain an explicit dispatch boundary.
4. For non-instant support, implement `apply_noninstant!` for
   `ConstantHamiltonianEvolution` and the required background helpers (`krausops`,
   `lindbladop`, or `paulinoise`) by exact signature. `NonInstantGate` reuses ordinary
   `apply!` plus `uptotime!`; neither form is a yielded simulation process.
5. Check factor and trajectory semantics. Register initialization splits only symbolic
   `STensor`; numeric states are not inspected for separability. If the backend supports
   trajectory objects, document whether destructive operations sample, mix, or branch.
6. Register default representation behavior only after deciding its interaction with
   existing `Qubit` and `Qumode` defaults. An extension must not accidentally replace a
   default merely because its methods are more specific.
7. Add focused dispatch tests for supported and rejected combinations. Include
   multi-subsystem application, observable evaluation, traceout, chronological
   background evolution, and error cases. Then run the normal general shard because
   shared generic methods can change other backends.
8. Update the backend human guide and the
   [backend support matrix](backend-support.md). Describe partial capability
   by operation family rather than labeling the backend complete.

Check the support matrix before copying existing methods; it is the canonical record of
current default conflicts and partial or defective combinations.

## Anchors

- **Source:** [`src/representations.jl`](../../../src/representations.jl), [`src/traits_and_defaults.jl`](../../../src/traits_and_defaults.jl), and [`src/backends/`](../../../src/backends/) — extension seams and existing implementations.
- **Docs:** [`docs/src/backendsimulator.md`](../../../docs/src/backendsimulator.md) and [`docs/src/API_Interface.md`](../../../docs/src/API_Interface.md) — backend concepts and shared interface.
- **Test:** [`test/general/representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl) and [`test/general/noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl) — dispatch and evolution examples.

## Unresolved questions

- Is there a required minimum backend capability set, or are independently documented partial backends intentional?
- Should unsupported combinations use a shared diagnostic type?
