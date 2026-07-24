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
2. Implement symbolic conversion at the narrowest dispatch boundary. Preserve explicit
   unsupported cases as errors; avoid generic fallbacks that produce a numerically valid
   object with different physical semantics.
3. Supply the primitive methods required by shared register operations: composition,
   application, observation, traceout or projection, and time evolution as applicable.
   Prefer generic `tr`, display, or operation behavior when correct. Add specialization
   only where the representation cannot satisfy the generic contract.
4. Check factor and trajectory semantics. Register initialization splits only symbolic
   `STensor`; numeric states are not inspected for separability. If the backend supports
   trajectory objects, document whether destructive operations sample, mix, or branch.
5. Register default representation behavior only after deciding its interaction with
   existing `Qubit` and `Qumode` defaults. An extension must not accidentally replace a
   default merely because its methods are more specific.
6. Add focused dispatch tests for supported and rejected combinations. Include
   multi-subsystem application, observable evaluation, traceout, chronological
   background evolution, and error cases. Then run the normal general shard because
   shared generic methods can change other backends.
7. Update the backend human guide and this support matrix. Describe partial capability
   by operation family rather than labeling the backend complete.

Before copying existing code, note two current hazards: the `PauliNoise` backend helper
signatures are inconsistent with their callers, and Gabs implements only a subset of
the common surface. Those are review evidence, not templates.

## Anchors

- **Source:** [`src/representations.jl`](../../../src/representations.jl), [`src/traits_and_defaults.jl`](../../../src/traits_and_defaults.jl), and [`src/backends/`](../../../src/backends/) — extension seams and existing implementations.
- **Docs:** [`docs/src/backendsimulator.md`](../../../docs/src/backendsimulator.md) and [`docs/src/API_Interface.md`](../../../docs/src/API_Interface.md) — backend concepts and shared interface.
- **Test:** [`test/general/representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl) and [`test/general/noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl) — dispatch and evolution examples.

## Unresolved questions

- Is there a required minimum backend capability set, or are independently documented partial backends intentional?
- Should unsupported combinations use a shared diagnostic type?
