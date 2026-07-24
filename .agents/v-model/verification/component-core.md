# Core Component Verification

These focused actions check register, time, metadata, notification, and numerical-adapter
invariants with discriminating fixtures.

## UNITV-001 — Verify ownership and composition modes

- **Covers:** CMP-001, CMP-002
- **Method:** test
- **Procedure:** Traverse ownership after initialization, multi-owner composition, slot
  swap, single and complete removal, and padded removal; separately apply an operation
  and an observable to two of three explicit tensor factors.
- **Environment / configuration:** Root test environment with stable owner identities,
  subsystem indexes, and a reusable full-invariant checker.
- **Pass criterion:** After every mutation, each assigned slot has exactly one matching
  live owner position, each non-padding live position has exactly one matching slot,
  positions are not duplicated, and every unassigned slot has index zero. The operation
  makes only its two factors share persistent ownership; the observable returns the
  expected value while all three original owner identities and indexes remain unchanged.
- **Status:** implemented
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`apply_tests.jl`](../../../test/general/apply_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl), [`traceout_tests.jl`](../../../test/general/traceout_tests.jl)
- **Nonconformance:** No reusable traversal covers every mutation, including swap and
  padded removal; explicit factor identities and post-observable owner identities are
  not all asserted.

## UNITV-002 — Verify complete shared-state deletion

- **Covers:** CMP-003
- **Method:** test
- **Procedure:** Trace out two complete shared-state groups in interleaved request order
  with an instrumented reduction hook and RNG, then trace an incomplete group.
- **Environment / configuration:** Root test environment with deterministic RNG state
  and a reduction hook that records order and fails if called for a complete group.
- **Pass criterion:** Complete-group deletion invokes no reduction hook, consumes no
  random sample, clears all mappings, and returns results in request order; incomplete
  deletion invokes the reduction hook one slot at a time in request order.
- **Status:** implemented
- **Evidence:** [`traceout_tests.jl`](../../../test/general/traceout_tests.jl)
- **Nonconformance:** Current complete-group cases do not record representation-hook
  order for an incomplete multi-slot group; only selected layouts are covered.

## UNITV-003 — Verify chronological background evolution

- **Covers:** CMP-004
- **Method:** test
- **Procedure:** Advance three shared-state slots with `t1 < t2 < t3`, distinct
  recording backgrounds, and target `T > t3`; then request a target below one selected
  access time.
- **Environment / configuration:** Root test environment with a recording background
  that identifies active slots and chronological segment durations.
- **Pass criterion:** The trace shows slot one active for `T-t1`, slot two for `T-t2`,
  and slot three for `T-t3` across ascending access-time segments; all selected times
  become `T`, and the earlier target reports a rewind error.
- **Status:** implemented
- **Evidence:** [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** No recording-background fixture asserts three distinct
  access-time groups and their chronological durations; backend cases differ.

## UNITV-004 — Verify fixed tag shapes and query order

- **Covers:** CMP-005
- **Method:** test
- **Procedure:** Generate interleaved duplicate heads and slots with stable IDs, then
  compare every exact, wildcard, predicate, slot-filtered, and head-filtered query in
  both directions with and without secondary indexes; probe malformed selectors.
- **Environment / configuration:** Root test environment with a canonical full-scan
  oracle and predicates that distinguish every record.
- **Pass criterion:** Indexed and canonical scans return identical identities and order
  newest-first and oldest-first; wrong-length patterns return no match, and a
  non-Boolean predicate reports failure.
- **Status:** implemented
- **Evidence:** [`abstract_tag_contract_tests.jl`](../../../test/general/abstract_tag_contract_tests.jl), [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl)
- **Nonconformance:** No generated canonical-scan comparison exists; wrong-length and
  non-Boolean predicate failures lack focused assertions.

## UNITV-005 — Verify register generations and message wake queues

- **Covers:** CMP-006
- **Method:** test
- **Procedure:** Attach several resource waiters including one that re-waits in a
  same-time wake cascade and issue two changes; separately issue two unattended message
  arrivals, three waits, and one future arrival.
- **Environment / configuration:** Root test environment with deterministic scheduling
  and retained messages inspected before explicit consumption.
- **Pass criterion:** All first-generation resource waiters wake on the first change,
  and the re-waiter wakes again only on the second. Message wait times are immediate,
  immediate, and the future arrival time, while all three messages remain queryable
  until explicitly consumed.
- **Status:** implemented
- **Evidence:** [`semaphore_2_tests.jl`](../../../test/general/semaphore_2_tests.jl), [`semaphore_3_tests.jl`](../../../test/general/semaphore_3_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl)
- **Nonconformance:** Current finite schedules do not establish the full resource
  generation and three-wait message sequence in one promotion fixture.

## UNITV-008 — Verify backend manifolds and dispatch exits

- **Covers:** CMP-009
- **Method:** test
- **Procedure:** Apply each designated initialization, composition, operation,
  observation, measurement, background, and reduction subset to pure exact, mixed exact,
  Monte Carlo trajectory, stabilizer, and Gaussian fixtures; probe unsupported
  stabilizer and Gaussian requests.
- **Environment / configuration:** Root test environment with type, manifold,
  normalization, and statistically bounded result assertions.
- **Pass criterion:** Each supported result stays in or performs the documented
  promotion from its starting manifold; all-trajectory composition and supported
  evolution remain trajectories, trajectory-plus-mixed composition becomes mixed, and
  designated unsupported stabilizer and Gaussian requests do not report success.
- **Status:** implemented
- **Evidence:** [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl)
- **Nonconformance:** Current coverage is not the full designated subset matrix, and
  unsupported stabilizer/Gaussian exits are not asserted for every requested class.
