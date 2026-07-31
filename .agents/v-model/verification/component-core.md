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
  recording backgrounds, and interaction target `T > t3`; retain an unrelated slot at
  its original local time.
- **Environment / configuration:** Root test environment with a recording background
  that identifies active slots and chronological segment durations.
- **Pass criterion:** The trace shows slot one active for `T-t1`, slot two for `T-t2`,
  and slot three for `T-t3` across ascending access-time segments; all selected times
  become `T`, no time decreases, and the unrelated slot's local time is unchanged.
- **Status:** implemented
- **Evidence:** [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl), [`noninstant_and_backgrounds_qumode_tests.jl`](../../../test/general/noninstant_and_backgrounds_qumode_tests.jl)
- **Nonconformance:** No recording-background fixture asserts three distinct
  access-time groups, chronological durations, synchronized selected times, and an
  untouched unrelated local time; backend cases differ.

## UNITV-004 — Verify fixed tag shapes and query order

- **Covers:** CMP-005
- **Method:** test
- **Procedure:** Inventory every public tag head and its ordered layout against the
  prior SemVer-compatible schema, then generate interleaved duplicate heads/slots and
  compare every exact, wildcard, predicate, slot-filtered, and head-filtered query in
  both directions with and without secondary indexes; probe malformed selectors.
- **Environment / configuration:** Root test environment with a public schema manifest,
  canonical full-scan oracle, and predicates that distinguish every record.
- **Pass criterion:** Indexed and canonical scans return identical identities and order
  newest-first and oldest-first; wrong-length patterns return no match, and a
  non-Boolean predicate reports failure. Every public tag name and ordered field layout
  matches the SemVer-compatible manifest.
- **Status:** implemented
- **Evidence:** [`abstract_tag_contract_tests.jl`](../../../test/general/abstract_tag_contract_tests.jl), [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl)
- **Nonconformance:** No public tag-schema manifest or generated canonical-scan
  comparison exists; wrong-length and non-Boolean predicate failures lack focused
  assertions.

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

## UNITV-008 — Verify representation manifolds and conversion policy

- **Covers:** CMP-009
- **Method:** test
- **Procedure:** Apply every capability class to QuantumOptics, Monte Carlo, stabilizer,
  Gaussian, and mixed-representation fixtures; inspect stored representations,
  approximation configuration, warnings, explicit twirling, and no-method exits.
- **Environment / configuration:** Root tests with discriminating states/operations,
  one configured approximate general representation, warning capture at repeated call
  sites, and a configurable twirling fixture.
- **Pass criterion:** Qubit and qumode defaults are QuantumOptics; explicit Clifford
  and Gabs choices remain specialized, and Monte Carlo remains a general peer.
  Directly supported requests preserve their manifold. Specialized or mixed requests
  lacking direct support convert to a common compatible general representation across initialization,
  composition, operation, observation, measurement, background, reduction, evolution,
  and transport while preserving configured approximation parameters. A degrading
  conversion warns once per call site with initial and final representation names.
  No general-to-specialized conversion occurs without an explicit twirling object.
  The absence of any applicable path yields a `MethodError` with an optional hint.
- **Status:** planned
- **Evidence:** [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl)
- **Nonconformance:** Defaults and Monte Carlo manifold behavior have partial evidence,
  and one Clifford observable conversion warns. Uniform promotion, approximation
  parameters, general-to-specialized twirling, and complete MethodError/hint coverage
  are absent.
