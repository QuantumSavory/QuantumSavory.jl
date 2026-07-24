# Register State, Operation, Metadata, and Inspection Contracts

## SUB-002 — Maintain logical state ownership and explicit factorization

- **Normative statement:** The register-state boundary shall maintain a bidirectional
  mapping between every assigned logical slot and exactly one subsystem position in a
  logical state owner, represent unassigned slots explicitly, and preserve tensor
  factors that are explicit in supported symbolic input until composition is required.
- **Parents:** SYS-002
- **Acceptance criterion:** Given unassigned slots and an explicitly factorized state,
  initialization gives every slot one reciprocal owner position and every factor a
  distinct owner; removing a slot clears both mapping directions without invalidating
  survivors.
- **Verification:** INTV-001 (test)
- **Context:** [Register model](../../context/core/register-model.md)

### Boundary semantics

- **Inputs:** Logical slot references, a supported state with matching subsystem arity,
  and an optional access time.
- **Outputs:** Assignment of each destination slot to a logical state owner and owner
  position.
- **State:** Assignment, removal, swap, and composition update both slot-to-owner and
  owner-to-slot directions.
- **Errors:** Arity mismatch and assignment into an already assigned destination report
  failure. This contract does not specify one error type or rollback after a partial
  multi-slot failure.

## SUB-003 — Coordinate register operations with state and time

- **Normative statement:** The register-operation boundary shall synchronize every
  selected assigned slot to the requested time, compose only the logical states needed
  for a state-changing multi-slot operation, avoid persistent ownership changes for a
  read-only observable, and update or remove ownership consistently after destructive
  measurement or traceout.
- **Parents:** SYS-002, SYS-003
- **Acceptance criterion:** Given separate factors with distinct access times, a later
  coupling advances and composes selected slots, a cross-factor observable returns its
  expected value without persistent composition, and destructive measurement or
  removal unassigns its target while survivor mappings remain consistent.
- **Verification:** INTV-001 (test)
- **Context:** [Register operations](../../context/core/register-operations.md)

### Boundary semantics

- **Inputs:** One or more logical slots, a supported operation, observable, measurement,
  or removal request, and an optional requested time.
- **Outputs:** Updated logical state, an observation or measurement result, or cleared
  assignment, according to the requested operation.
- **State:** State-changing operations may compose owners permanently; read-only
  observations may compose temporary state without changing ownership.
- **Errors:** Unassigned required input, unsupported capability, dimension mismatch, or
  time rewind reports failure. Atomic rollback after a multi-slot failure is not
  guaranteed.

## SUB-005 — Preserve tag and query-store semantics

- **Normative statement:** The metadata boundary shall store supported fixed-shape tag
  values, preserve documented insertion order independently of lookup indexes, and
  provide exact, wildcard, predicate, observation, and consumption query modes with
  store-specific result shapes. Register entries shall expose stable identity, slot,
  and simulated timestamp; message results shall expose buffer depth and source rather
  than a public identity or timestamp.
- **Parents:** SYS-005
- **Acceptance criterion:** Given duplicate and distinct tags in both store kinds,
  register exact, wildcard, predicate, FIFO/FILO, resource-filter, observation, and
  consumption modes match a canonical scan and return slot, stable identity, tag, and
  time; message exact, wildcard, predicate, FIFO observation, and consumption match
  their canonical scan and return depth or source plus tag as documented. Observation
  removes nothing and consumption removes only its result while subsequent queries
  remain consistent.
- **Verification:** INTV-003 (test)
- **Context:** [Metadata and waits](../../context/core/metadata-and-waits.md)

### Boundary semantics

- **Inputs:** A supported tag shape, target store or slot, query patterns, optional
  predicates, ordering selection, and resource-state filters where supported.
- **Outputs:** No match, one match, all supported register matches, or one consumed
  match with the store-specific result metadata.
- **State:** Tag insertion and deletion update the canonical ordered store and all
  secondary indexes as one synchronous operation.
- **Errors:** Unsupported tag shapes, invalid predicates, deletion of an unknown
  register identity, or an unsupported store/query-mode combination report failure.

## SUB-006 — Separate matching waits from change notification

- **Normative statement:** The wait boundary shall check for a matching query result
  before blocking, distinguish observing waits from consuming waits, avoid implicit
  resource reservation, and preserve the documented difference between future-edge
  resource notification and message-arrival notification with queued wakeups.
- **Parents:** SYS-004, SYS-005
- **Acceptance criterion:** Existing matches return immediately; observing waits retain
  them and consuming waits remove one. One future change or message wakes all current
  waiters, while each unattended message supplies one later immediate notification
  without consuming its message.
- **Verification:** INTV-002 (test)
- **Context:** [Metadata and waits](../../context/core/metadata-and-waits.md)

### Boundary semantics

- **Inputs:** A resource or message store, query pattern for matching waits, and an
  observing or consuming mode.
- **Outputs:** A process that returns the first matching snapshot or consumed entry
  after zero or more change notifications.
- **State:** Notifications do not reserve a resource or consume a stored entry.
  Consumption occurs only through the consuming query path.
- **Errors:** Cancellation and timeout policy are caller responsibilities unless a
  higher-level protocol adds them.

## SUB-015 — Expose register state inspection without mutation

- **Normative statement:** The register-inspection boundary shall expose whether a
  logical slot is assigned, its shared state-owner identity and subsystem membership,
  the owner's native numerical state, and documented text or HTML summaries without
  changing ownership, state, or access time.
- **Parents:** SYS-013
- **Acceptance criterion:** Given unassigned, separately assigned, and shared-state
  slots, inspection returns no owner for the unassigned slot, distinct owners for the
  separate slots, one shared owner whose member list contains exactly the shared slots,
  and the corresponding native state; repeating the inspection and rendering supported
  summaries leaves all owner identities, subsystem positions, state values, and access
  times unchanged.
- **Verification:** INTV-009 (test)
- **Context:** [Register model](../../context/core/register-model.md)

### Boundary semantics

- **Inputs:** A register, slot, or live shared-state owner and a supported display form.
- **Outputs:** Assignment/owner information, native state, member slots, or a rendered
  summary.
- **State:** Inspection is observational and shall not advance time or reassign state.
- **Errors:** Inspecting an unassigned slot returns the documented empty result; stale
  internal owners are outside the public contract.
