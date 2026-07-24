# Core Integration Verification

These actions exercise core subsystem boundaries and failure paths.

## INTV-001 — Verify symbolic, ownership, operation, and time integration

- **Covers:** SUB-001, SUB-002, SUB-003
- **Method:** test
- **Procedure:** Run built-in symbolic fixtures in two representations and an external
  lowering fixture; exercise factorized ownership, timed coupling, observation, and
  destructive mutation; compare core source and a built-in baseline before/after.
- **Environment / configuration:** Root tests plus a clean external package against the
  pinned revision.
- **Pass criterion:** Built-in symbolic state, operation, and observable fixtures
  produce expected preparation, effect, and result in both representations, while an
  incompatible fixture fails. The external lowering uses the same boundary, returns its
  asserted result without core changes, and leaves the built-in baseline unchanged.
  Initialization gives each slot one reciprocal owner and each factor a distinct owner;
  removal clears both directions without invalidating survivors. Later coupling
  advances and composes only selected factors, observation does not persist
  composition, and destructive mutation unassigns its target with survivors consistent.
- **Status:** implemented
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`apply_tests.jl`](../../../test/general/apply_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl), [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl)
- **Nonconformance:** No external lowering fixture or pre/post baseline exists. Built-in
  tests do not jointly cover both representations, factor identities, timed coupling,
  unchanged observed owners, survivor mappings, and incompatible lowering.

## INTV-002 — Verify scheduling against waits and notifications

- **Covers:** SUB-004, SUB-006
- **Method:** test
- **Procedure:** Run deterministic timeout, change, single-resource, paired-distinct-
  resource, observing, consuming, re-wait, unattended-message, and failing-process
  cases.
- **Environment / configuration:** Root tests with recorded event and ownership times.
- **Pass criterion:** No process resumes before its trigger, capacity is never
  exceeded, a waiter for distinct paired resources holds no partial acquisition while
  blocked, and process failure reaches the caller. Existing matches return immediately;
  observing waits retain and consuming waits remove one. A future change or message
  wakes all current waiters, while each unattended message supplies one later immediate
  notification without consuming its message.
- **Status:** implemented
- **Evidence:** [`concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`querywait_tests.jl`](../../../test/general/querywait_tests.jl), [`semaphore_2_tests.jl`](../../../test/general/semaphore_2_tests.jl), [`semaphore_3_tests.jl`](../../../test/general/semaphore_3_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl)
- **Nonconformance:** Failure propagation, no partial paired acquisition, and the
  distinct-resource precondition are unasserted; interleavings are selected.

## INTV-003 — Verify metadata consistency and protocol revalidation

- **Covers:** SUB-005, SUB-013
- **Method:** test
- **Procedure:** Compare register/message queries with canonical stores; run built-in
  and external protocol lifecycles with a pre-lock invalidation; compare core source
  and a built-in baseline before/after the external fixture.
- **Environment / configuration:** Root tests plus a clean external protocol package,
  duplicate tags, stable IDs, and injected stale data.
- **Pass criterion:** Register exact, wildcard, predicate, FIFO/FILO, and resource-
  filtered queries match the canonical scan and return slot, stable ID, tag, and time;
  message exact, wildcard, and predicate FIFO queries match their canonical scan,
  observation returns depth/source/tag, and consumption returns source/tag. Observation
  removes nothing, consumption removes only its result, and later queries/indexes stay
  consistent. Protocol pairs have reciprocal IDs; delayed updates affect only matching
  current/history state; an invalidated snapshot is not consumed; successful resources
  are removed exactly once. The external protocol uses the built-in boundary, changes
  no core source, and leaves the built-in baseline unchanged.
- **Status:** implemented
- **Evidence:** [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`protocolzoo_entanglement_consumer_stale_query_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_stale_query_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** No all-mode canonical comparison, external protocol, or pre/post
  baseline exists. Separate lifecycle tests do not jointly prove every field, matching
  update, stale rejection, and exactly-once removal.

## INTV-005 — Verify backend capability dispatch

- **Covers:** SUB-010
- **Method:** test
- **Procedure:** Run all confirmed built-in adapter cells and outside-matrix probes,
  then load an external numerical adapter and compare source plus a built-in baseline.
- **Environment / configuration:** Root matrix and a clean external package against the
  pinned revision.
- **Pass criterion:** Every designated built-in capability returns its documented
  manifold, subsystem count, and normalization or weight with exact, stochastic, or
  compact semantics; outside-matrix requests fail. The external adapter is selected
  through the same dispatch, returns its asserted result without core changes, and
  leaves the built-in baseline unchanged.
- **Status:** implemented
- **Evidence:** [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl)
- **Nonconformance:** The matrix is unconfirmed and partial; no external numerical
  adapter or pre/post baseline comparison exists.
