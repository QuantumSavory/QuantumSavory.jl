# Component Verification

## UNITV-001 — Verify ownership backreferences and composition modes

- **Covers:** CMP-001, CMP-002
- **Method:** test
- **Procedure:** Run register interface, apply, observable, and project/traceout unit suites.
- **Environment / configuration:** Root test environment with small qubit register fixtures.
- **Pass criterion:** State references retain asserted register/index backreferences; persistent operations join ownership; factorization separates asserted groups; observables across separate references return asserted results.
- **Status:** implemented
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`apply_tests.jl`](../../../test/general/apply_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`traceout_tests.jl`](../../../test/general/traceout_tests.jl)
- **Nonconformance:** No one traversal covers swap/padded removal, explicit-factor identities, or owner identities after temporary composition.

## UNITV-002 — Verify complete shared-state deletion

- **Covers:** CMP-003
- **Method:** test
- **Procedure:** Run the complete-group and grouped-deletion traceout cases.
- **Environment / configuration:** Root test environment with instrumented state references and deterministic RNG state.
- **Pass criterion:** Complete groups clear every slot/backreference without invoking backend reduction, preserve caller return order and RNG state, and partial/failing cases leave asserted backreference consistency.
- **Status:** implemented
- **Evidence:** [`traceout_tests.jl`](../../../test/general/traceout_tests.jl)
- **Nonconformance:** No test records representation-hook call order for an incomplete multi-slot group; layouts are selected cases.

## UNITV-003 — Verify chronological background evolution

- **Covers:** CMP-004
- **Method:** test
- **Procedure:** Run qubit, Clifford, and qumode noninstant/background cases.
- **Environment / configuration:** Root test environment with fixed access times and backend-specific background models.
- **Pass criterion:** Repeated and composed forward evolution agree with asserted reference states; supported channel decompositions meet tolerances; backwards access throws.
- **Status:** implemented
- **Evidence:** [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** No recording-background fixture asserts three distinct access-time groups and chronological segment durations; backend coverage differs.

## UNITV-004 — Verify fixed tag shapes and query order

- **Covers:** CMP-005
- **Method:** test
- **Procedure:** Run abstract-tag contract and tag/query index suites.
- **Environment / configuration:** Root test environment with heterogeneous tag heads, predicates, duplicates, and insertion orders.
- **Pass criterion:** Concrete and custom tags retain their declared shape; exact/predicate/wildcard matching returns asserted items; FIFO/FILO order and checked deletion follow stable IDs and update indexes consistently.
- **Status:** implemented
- **Evidence:** [`abstract_tag_contract_tests.jl`](../../../test/general/abstract_tag_contract_tests.jl), [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl)
- **Nonconformance:** No generated canonical-scan comparison exists; wrong-length queries and non-Boolean predicates lack focused failure assertions.

## UNITV-005 — Verify register generations and message wake queues

- **Covers:** CMP-006
- **Method:** test
- **Procedure:** Run same-timestamp register cascade and buffered/future message-wakeup cases.
- **Environment / configuration:** Root test environment with deterministic concurrent senders and waiters.
- **Pass criterion:** Register change waits observe same-timestamp cascades after re-wait; buffered messages wake later waiters immediately one arrival at a time; future arrivals wake blocked waiters at the asserted time.
- **Status:** implemented
- **Evidence:** [`semaphore_2_tests.jl`](../../../test/general/semaphore_2_tests.jl), [`semaphore_3_tests.jl`](../../../test/general/semaphore_3_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl)
- **Nonconformance:** The finite schedules do not prove freedom from lost wakeups for all interleavings.

## UNITV-006 — Verify directional delays and explicit forwarding

- **Covers:** CMP-007
- **Method:** test
- **Procedure:** Run per-direction RegisterNet delay cases and protocol delete-forwarding cases.
- **Environment / configuration:** Root test environment on directed link fixtures with distinct delays and pair identities.
- **Pass criterion:** Opposite directions retain distinct configured delays, direct classical delivery occurs at its asserted time, and a protocol-forwarded delete reaches the asserted next-hop buffer with preserved identity.
- **Status:** implemented
- **Evidence:** [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** No focused transport test distinguishes direct delivery from explicit multi-hop forwarding, and malformed network/count inputs lack direct assertions.

## UNITV-007 — Verify guarded quantum ownership transfer

- **Covers:** CMP-008
- **Method:** test
- **Procedure:** Run direct quantum-channel constructor, transfer, noise, and occupied-destination cases.
- **Environment / configuration:** Root test environment with zero/nonzero delays and qubit backgrounds.
- **Pass criterion:** Transfer vacates the source, attaches the destination to the same state reference, applies the asserted T1/T2 transit behavior, and throws before overwriting an initialized destination.
- **Status:** implemented
- **Evidence:** [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** In-transit backreference replacement, pre-arrival destination state, cancellation, and simultaneous takes are not directly asserted.

## UNITV-008 — Verify backend manifolds and dispatch exits

- **Covers:** CMP-009
- **Method:** test
- **Procedure:** Run representation dispatch, Monte Carlo lifecycle/statistics, and Gaussian homodyne projection suites.
- **Environment / configuration:** Root test environment with fixed or statistically bounded fixtures for each cited backend.
- **Pass criterion:** Supported operations preserve the asserted backend type; documented mixed operations deliberately promote where asserted; observables/statistics meet their specified tolerances.
- **Status:** implemented
- **Evidence:** [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl)
- **Nonconformance:** The backend matrix remains partial and unsupported-operation exceptions lack a uniform asserted contract.

## UNITV-009 — Verify state-catalog parameter/expression alignment

- **Covers:** CMP-010
- **Method:** test
- **Procedure:** Run StateZoo parameter/range and symbolic-expression API cases.
- **Environment / configuration:** Root test environment using each catalog entry's declared `good` parameters.
- **Pass criterion:** Every enumerated state accepts parameters in declared order, initializes a register, has matching symbolic/expressed trace, and satisfies the explicitly asserted normalization checks.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl)
- **Nonconformance:** Physical formulas and range endpoints are weakly checked; normalization is asserted for only one family; `test/test_stateszoo_depolarized.jl` is not discovered.

## UNITV-010 — Verify immediate destructive circuit behavior

- **Covers:** CMP-011
- **Method:** test
- **Procedure:** Run CircuitZoo API, swap, fusion, superdense, and purification cases.
- **Environment / configuration:** Root test environment on explicitly initialized local/remote register slots.
- **Pass criterion:** Each cited direct call returns its asserted result shape, preserves asserted output fidelity, and clears or retains the slots checked by its focused test.
- **Status:** implemented
- **Evidence:** [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), [`circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl), [`circuitzoo_superdense_tests.jl`](../../../test/general/circuitzoo_superdense_tests.jl), [`circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl)
- **Nonconformance:** No test asserts zero simulated-time advance; several Node variants and Stringent return/destructive shapes are incomplete.

## UNITV-011 — Verify protocol snapshots and pair identity

- **Covers:** CMP-012
- **Method:** test
- **Procedure:** Run pair-ID algebra/history, stale counterpart/query, tracker lock-gap, and switch stale-state cases.
- **Environment / configuration:** Root test environment with deterministic IDs plus injected delayed, deleted, and reused-slot metadata.
- **Pass criterion:** Pair IDs combine with asserted algebra, snapshots are revalidated before mutation, delayed updates cannot overwrite a fresh reused slot, stale paths release locks, and delete/update history advances the asserted identity.
- **Status:** implemented
- **Evidence:** [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl), [`protocolzoo_entanglement_counterpart_invariant_tests.jl`](../../../test/general/protocolzoo_entanglement_counterpart_invariant_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), [`myswapper_tutorial_tests.jl`](../../../test/examples/myswapper_tutorial_tests.jl)
- **Nonconformance:** QTCP/MBQC control-flow tests do not establish delivered fidelity/corrections, and some consumer/grid fixtures have weak or conditional assertions.

## UNITV-012 — Verify primitive log contexts and optional activation

- **Covers:** CMP-013
- **Method:** test
- **Procedure:** Run structured logging/filtering, InteractiveUtils, Cairo/GL, and PNG-show cases.
- **Environment / configuration:** Root tests followed by the plotting project so optional dependencies activate extensions explicitly.
- **Pass criterion:** Log contexts contain the asserted primitive field order/types and snapshots, rejected logs avoid message/context evaluation, and each cited optional extension entry point completes in its configured environment.
- **Status:** implemented
- **Evidence:** [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl)
- **Nonconformance:** Event vocabulary is sampled, rendering is smoke-only, and absent/partial/full optional-dependency activation is not tested cleanly.
