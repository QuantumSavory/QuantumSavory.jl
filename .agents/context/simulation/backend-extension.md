# Backend Extension

- **Context need:** Task playbook
- **Open when:** Implementing or repairing a representation backend or its symbolic lowering.
- **Do not open when:** Only comparing existing support or changing a backend-independent protocol.
- **Related specification IDs:** STK-004, SYS-007, SYS-009, SUB-001, SUB-010, CMP-009
- **Review when:** Backend extension seams, representation traits, or the shared operation interface changes.

## Implement or repair a backend

QuantumSavory's documented, exported backend generics form a supported extension
interface for both repository-owned backends and external libraries. A backend declares
support capability by capability; implementing one lowering or operation does not imply
support for the complete register API.

1. Define the representation and state types at the existing representation seam.
   Decide explicitly which symbolic state families, operations, observables, backgrounds,
   and destructive operations are in scope. Do not claim whole-backend support from one
   successful lowering method.
2. Implement symbolic lowering and representation selection deliberately:
   `newstate(trait, repr)`, `express_nolookup(symbolic, repr)`, `default_repr(native)`,
   and `consistent_representation(...)` where mixed slot preferences need a policy.
   The current consistency helper rejects mixed representations rather than promoting
   them.
3. Supply `nsubsystems`, `subsystemcompose`, and native `apply!` for the state and
   operation combinations actually supported. Add `observable`, `project_traceout!`,
   backend partial `traceout!`, and `uptotime!` only for their documented capabilities.
   Keep unsupported combinations as meaningful `MethodError` dispatch boundaries;
   targeted error hints may add guidance without replacing that signal.
4. For background evolution, implement the documented `uptotime!` and required
   `krausops`, `lindbladop`, or `paulinoise` signatures. `NonInstantGate` reuses
   ordinary `apply!` plus `uptotime!`; neither form is a yielded simulation process.
   Built-in `ConstantHamiltonianEvolution` support also dispatches through the
   undocumented `apply_noninstant!` helper, which is not part of the external backend
   contract.
5. Check factor and trajectory semantics. Register initialization splits only symbolic
   `STensor`; numeric states are not inspected for separability. If the backend supports
   trajectory objects, document whether destructive operations sample, mix, or branch.
6. Preserve `QuantumOpticsRepr` as the slot default for both `Qubit` and `Qumode`.
   Specialized Gabs or Clifford methods must not replace a trait default merely because
   they are more specific.
7. Add focused dispatch tests for supported and rejected combinations. Include
   multi-subsystem application, observable evaluation, traceout, chronological
   background evolution, and error cases. Then run the normal general shard because
   shared generic methods can change other backends.
8. Update the backend human guide and the
   [backend support matrix](backend-support.md). Describe partial capability
   by operation family rather than labeling the backend complete.

Check the support matrix before copying existing methods; it is the canonical record of
partial and defective combinations. Do not add one-off conversions as a substitute for
the planned common promotion policy: generic promotion, approximation parameters, and
explicit twirling-based specialization are not implemented yet.

Repository backends may additionally use private storage helpers such as
`_wrap_state_for_slots` for `MCKet`. Such helpers are not requirements for an external
backend; the supported seam is the documented generic-function dispatch above.

## Anchors

- **Source:** [`src/representations.jl`](../../../src/representations.jl), [`src/traits_and_defaults.jl`](../../../src/traits_and_defaults.jl), and [`src/backends/`](../../../src/backends/) — extension seams and existing implementations.
- **Docs:** [`docs/src/backendsimulator.md`](../../../docs/src/backendsimulator.md) and [`docs/src/API_Interface.md`](../../../docs/src/API_Interface.md) — backend concepts and shared interface.
- **Test:** [`test/general/representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl) and [`test/general/noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl) — dispatch and evolution examples.

## Known gaps

- Automatic specialized-to-general and mixed-representation promotion is absent.
- General-to-specialized conversion and its configurable twirling object are absent.
- Promotion does not yet select or propagate representation-specific approximation
  settings; `QuantumOpticsRepr` already exposes its independent finite-basis `cutoff`.
- The documented unexported `default_repr` extension function lacks a `public`
  declaration.
- No conformance fixture implements a small external backend and exercises the complete
  documented extension path independently of repository backend internals.
