# Core Integration Verification

These actions exercise core subsystem boundaries and failure paths.

## INTV-001 — Verify symbolic, ownership, operation, and time integration

- **Covers:** SUB-001, SUB-002, SUB-003
- **Method:** test
- **Procedure:** Run built-in symbolic state, operation, and observable fixtures in two
  representations; exercise factorized ownership, forward-time coupling, observation,
  and successful destructive mutation.
- **Environment / configuration:** Root tests with explicit tensor factors, distinct
  local access times, and two designated compatible representations.
- **Pass criterion:** Built-in symbolic state, operation, and observable fixtures
  produce expected preparation, effect, and result in both representations.
  Initialization gives each slot one reciprocal owner and each factor a distinct owner;
  removal clears both directions without invalidating survivors. Later coupling
  advances selected factors to the interaction time and composes only those factors;
  observation does not persist
  composition, and destructive mutation unassigns its target with survivors consistent.
- **Status:** implemented
- **Evidence:** [`register_interface_tests.jl`](../../../test/general/register_interface_tests.jl), [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`apply_tests.jl`](../../../test/general/apply_tests.jl), [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`project_traceout_tests.jl`](../../../test/general/project_traceout_tests.jl), [`noninstant_and_backgrounds_qubit_tests.jl`](../../../test/general/noninstant_and_backgrounds_qubit_tests.jl)
- **Nonconformance:** Built-in tests do not jointly cover both representations, factor
  identities, local-time synchronization, unchanged observed owners, and survivor
  mappings. Symbolic/backend hooks are internal and are intentionally not tested as
  third-party seams.

## INTV-002 — Verify scheduling against waits and notifications

- **Covers:** SUB-004, SUB-006
- **Method:** test
- **Procedure:** Run controlled timeout, change, single-resource, paired-distinct-
  resource, observing, consuming, re-wait, unattended-message, equal-time independent
  and causally ordered, and failing-process cases.
- **Environment / configuration:** Root tests with recorded event and ownership times.
- **Pass criterion:** No process resumes before its trigger, capacity is never
  exceeded, a waiter for distinct paired resources holds no partial acquisition while
  blocked, and process failure reaches the caller. Existing matches return immediately;
  observing waits retain and consuming waits remove one. A future change or message
  wakes all current waiters, while each unattended message supplies one later immediate
  notification without consuming its message. No post-exception simulation-state
  condition is asserted. Independent equal-time actions have no asserted relative
  order, while explicit event or resource dependencies are respected.
- **Status:** implemented
- **Evidence:** [`concurrentsim_helpers_tests.jl`](../../../test/general/concurrentsim_helpers_tests.jl), [`querywait_tests.jl`](../../../test/general/querywait_tests.jl), [`semaphore_2_tests.jl`](../../../test/general/semaphore_2_tests.jl), [`semaphore_3_tests.jl`](../../../test/general/semaphore_3_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl)
- **Nonconformance:** Failure propagation, no partial paired acquisition, and the
  distinct-resource precondition are unasserted. No fixture separates causal ordering
  from incidental equal-time tie-breaking.

## INTV-003 — Verify metadata consistency and protocol revalidation

- **Covers:** SUB-005, SUB-013
- **Method:** test
- **Procedure:** Compare register/message queries with canonical stores, then run
  built-in protocol lifecycles with a snapshot retained across a yield and invalidated
  before locking.
- **Environment / configuration:** Root tests with duplicate tags, stable IDs, injected
  stale data, and recorded lock ownership.
- **Pass criterion:** Register exact, wildcard, predicate, FIFO/FILO, and resource-
  filtered queries match the canonical scan and return slot, stable ID, tag, and time;
  message exact, wildcard, and predicate FIFO queries match their canonical scan,
  observation returns depth/source/tag, and consumption returns source/tag. Observation
  removes nothing, consumption removes only its result, and later queries/indexes stay
  consistent. Protocol pairs have reciprocal IDs; delayed updates affect only matching
  current/history state. `query_wait` creates no lock or reservation; the protocol
  locks and revalidates before mutation, an invalidated snapshot is not consumed, and
  successful resources are removed exactly once.
- **Status:** implemented
- **Evidence:** [`tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`protocolzoo_entanglement_consumer_stale_query_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_stale_query_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** No all-mode canonical comparison exists. Separate lifecycle tests
  do not jointly prove every field, absence of an implicit wait lock, matching update,
  stale rejection, and exactly-once removal. Protocol lifecycle hooks are internal.

## INTV-005 — Verify backend dispatch and representation conversion

- **Covers:** SUB-010
- **Method:** test
- **Procedure:** Run the built-in capability matrix across initialization, composition,
  operations, observables, measurement, traceout, backgrounds, non-instant evolution,
  and transport; force constrained and mixed representations to a common general
  representation and probe no-method dispatch.
- **Environment / configuration:** Root matrix with exact, Monte Carlo, stabilizer, and
  Gaussian states, captured warnings, and configured representation approximation
  parameters.
- **Pass criterion:** Each designated capability returns its documented manifold,
  subsystem count, normalization or weight, and physical result. A constrained or mixed
  request that lacks direct support converts state and operation data to a compatible
  common general representation for every capability class, retains representation
  configuration, and warns once per call site with initial and final representation
  names. Monte Carlo remains general rather than being forced to another
  representation. A supported general input plus explicit twirling object converts to
  the requested specialized representation with the object's declared semantics;
  without that object it remains general. When no method or conversion applies,
  dispatch produces a `MethodError` with any hint remaining supplemental.
- **Status:** planned
- **Evidence:** [`representations_dispatch_tests.jl`](../../../test/general/representations_dispatch_tests.jl), [`quantummc_repr_tests.jl`](../../../test/general/quantummc_repr_tests.jl), [`project_traceout_gabs_homodyne_tests.jl`](../../../test/general/project_traceout_gabs_homodyne_tests.jl), [`noninstant_and_backgrounds_clifford_tests.jl`](../../../test/general/noninstant_and_backgrounds_clifford_tests.jl)
- **Nonconformance:** The built-in matrix is partial. Only selected conversion paths
  exist; uniform promotion and propagation of configured representation approximation
  settings, explicit twirling, warning policy, and complete MethodError/hint coverage
  are unimplemented. Backend hooks are internal rather than third-party extension
  contracts.
