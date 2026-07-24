# Core Simulation Component Contracts

## CMP-001 — Preserve bidirectional state ownership

- **Normative statement:** For every live logical state-owner position, either the
  position is an intentional padding hole or it identifies one assigned register slot
  whose owner and subsystem index point back to that same position; every assigned slot
  shall likewise identify exactly one live owner position.
- **Parents:** SUB-002
- **Acceptance criterion:** Given state initialization, multi-owner composition, slot
  swap, single-slot removal, complete-state removal, and padded-state removal fixtures,
  when each mutation completes, then a full traversal finds no assigned slot without
  one matching owner position, no live owner position without one matching assigned
  slot, no duplicate owner position, and every unassigned slot has a zero subsystem
  index.
- **Verification:** UNITV-001 (test)
- **Origin / risk:** Current state-reference invariant and regression helpers;
  maintainer confirmation pending; critical state-corruption risk
- **Context:** [Register model](../../context/core/register-model.md)

## CMP-002 — Distinguish explicit factorization, persistent composition, and temporary composition

- **Normative statement:** Initialization shall preserve tensor factors explicitly
  present in a supported symbolic tensor expression, a state-changing operation across
  distinct owners shall persistently compose only the touched owners, and a read-only
  observable across distinct owners shall use a temporary composition without changing
  persistent ownership.
- **Parents:** SUB-002, SUB-003
- **Acceptance criterion:** Given three slots initialized from three explicit symbolic
  tensor factors, when a supported two-slot operation touches the first two, then those
  two and only those two share persistent ownership; given a fresh equivalent fixture,
  when a two-slot observable instead touches the first two, then it returns the expected
  value and all three original owner identities and subsystem indices remain unchanged.
- **Verification:** UNITV-001 (test)
- **Origin / risk:** Current initialization, operation, and observable behavior;
  maintainer confirmation pending; high memory and state-identity risk
- **Context:** [Register operations](../../context/core/register-operations.md)

## CMP-003 — Delete complete shared-state groups without unnecessary reduction

- **Normative statement:** A multi-slot traceout request that contains every live slot
  of a shared logical state shall clear the complete ownership group without invoking
  representation-level partial reduction or consuming randomness; incomplete groups
  shall be reduced in argument order, and the return order shall match the request
  order.
- **Parents:** SUB-002, SUB-003
- **Acceptance criterion:** Given two complete shared-state groups presented in
  interleaved request order and a representation-level reduction hook that fails if
  called, when all live slots are traced out in one request, then no reduction hook is
  called, no random sample is consumed, all mappings are cleared, and results follow
  request order; given an incomplete group, then reduction hooks are called one slot at
  a time in request order.
- **Verification:** UNITV-002 (test)
- **Origin / risk:** Grouped traceout implementation and regression tests; maintainer
  confirmation pending; high stochastic-semantics risk
- **Context:** [Register operations](../../context/core/register-operations.md)

## CMP-004 — Evolve backgrounds in chronological access-time groups

- **Normative statement:** When selected slots share one state owner but have different
  access times, background evolution shall proceed through ascending access-time
  boundaries so each slot's background acts only after that slot becomes active, after
  which all selected slots receive the requested target time; a target earlier than a
  selected access time shall report a rewind error.
- **Parents:** SUB-003
- **Acceptance criterion:** Given three shared-state slots with access times `t1 < t2 <
  t3`, distinct recording backgrounds, and target `T > t3`, when they are advanced
  together, then the recording trace shows slot one active for `T-t1`, slot two for
  `T-t2`, and slot three for `T-t3` across chronological segments and all selected
  access times become `T`; when a target below any selected access time is requested,
  the call reports a rewind error.
- **Verification:** UNITV-003 (test)
- **Origin / risk:** Current grouped time-evolution algorithm; maintainer confirmation
  pending; critical temporal-physics risk
- **Context:** [Time and noise](../../context/simulation/time-and-noise.md)

## CMP-005 — Preserve fixed tag shapes and semantic query order

- **Normative statement:** A stored tag shall use one supported fixed payload shape,
  retain one stable insertion identity, and match only a same-length query whose fields
  satisfy exact, wildcard, or Boolean-predicate selectors. Any lookup acceleration
  shall preserve the result set, insertion order, and selected first-match direction
  observable from a canonical scan.
- **Parents:** SUB-005
- **Acceptance criterion:** Given interleaved duplicate tag heads and slots with stable
  identities, when every supported exact, wildcard, predicate, slot-filtered, and
  head-filtered query is run newest-first and oldest-first both with indexes populated
  and against a canonical full-scan oracle, then result identities and order are
  identical;
  a wrong-length pattern yields no match and a non-Boolean predicate reports failure.
- **Verification:** UNITV-004 (test)
- **Origin / risk:** Current tag shapes and query-order behavior; maintainer
  confirmation pending; high selection-correctness risk
- **Context:** [Metadata and waits](../../context/core/metadata-and-waits.md)

## CMP-006 — Distinguish register change generations from queued message wakeups

- **Normative statement:** A resource change shall wake every waiter already blocked
  for that future change, while a waiter that blocks again after waking shall require a
  later change. A message arrival shall wake every currently blocked message waiter or,
  if none exists, supply exactly one later immediate wakeup; neither kind of
  notification shall consume metadata or a message.
- **Parents:** SUB-006
- **Acceptance criterion:** Given multiple resource waiters including one that re-waits
  during a same-time wake cascade, when two changes occur, then all first-generation
  waiters wake for the first change and the re-waiter wakes a second time only for the
  second change; given two unattended message arrivals followed by three waits and one
  future arrival, then the wait completion times are immediate, immediate, and the
  future arrival time, while all three messages remain queryable until explicitly
  consumed.
- **Verification:** UNITV-005 (test)
- **Origin / risk:** Resource-change and queued-message wakeup regression tests;
  maintainer confirmation pending; critical lost-wakeup risk
- **Context:** [Metadata and waits](../../context/core/metadata-and-waits.md)

## CMP-009 — Preserve backend-specific state manifolds and dispatch boundaries

- **Normative statement:** Numerical dispatch shall preserve each supported adapter's
  documented state manifold: an exact-state path may promote pure state to mixed state
  when required, an all-trajectory path shall remain a pure-state trajectory where its
  supported operation permits, a stabilizer path shall not silently execute
  non-stabilizer semantics, and a Gaussian path shall accept only its supported
  Gaussian capabilities.
- **Parents:** SUB-010
- **Acceptance criterion:** Given pure exact, mixed exact, Monte Carlo trajectory,
  stabilizer, and Gaussian fixtures, when supported initialization, composition,
  operation, observation, measurement, background, and reduction subsets are applied,
  then each result remains in or performs the documented promotion from its starting
  manifold; all-trajectory composition and supported trajectory evolution remain
  trajectories, trajectory-plus-mixed composition becomes mixed, and designated
  unsupported stabilizer or Gaussian requests do not report success.
- **Verification:** UNITV-008 (test)
- **Origin / risk:** Backend-specific state behavior and representation tests;
  maintainer confirmation pending; critical physical-semantics risk
- **Context:** [Backend support](../../context/simulation/backend-support.md)

## Component limitations

- Explicit symbolic tensor structure, not generic numerical separability analysis,
  defines the factorization guarantee.
- A rewind error is required, but this draft does not promise that a failing multi-slot
  call rolls back work performed before the error is detected.
- Unsupported adapters do not yet share one exception type or diagnostic vocabulary.
- No adapter-independent accuracy, performance, or scale budget is specified.
