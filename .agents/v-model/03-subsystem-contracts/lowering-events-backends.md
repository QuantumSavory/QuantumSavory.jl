# Symbolic Lowering, Event, and Backend Contracts

## SUB-001 — Preserve the symbolic-to-representation boundary

- **Normative statement:** The symbolic boundary shall combine a supported symbolic
  description, its intended use as state, operation, or observable, and the involved
  subsystem representation preferences to produce a semantically corresponding native
  object only for a compatible capability combination. An external symbolic type shall
  participate through the same documented lowering dispatch without core source
  changes.
- **Parents:** SYS-001, SYS-007, SYS-009
- **Acceptance criterion:** Given supported symbolic state, operation, and observable
  fixtures, lowering for two compatible representations produces native objects with
  the expected preparation, operation effect, and observable result; an incompatible
  fixture does not report success; and an external symbolic fixture is selected through
  the same boundary without changing a built-in baseline result.
- **Verification:** INTV-001 (test)
- **Context:** [Backend support](../../context/simulation/backend-support.md)

### Boundary semantics

- **Inputs:** A supported symbolic description, intended use, and involved subsystem
  traits and representation preferences.
- **Outputs:** A native state, operation, or observable compatible with the selected
  representation.
- **State:** Lowering itself does not assign or mutate logical subsystem ownership;
  the consuming operation owns that mutation.
- **Errors:** Incompatible capabilities shall not be reported as successful. One common
  unsupported-capability error type is not specified.

## SUB-004 — Schedule resumable events and exclusive resources

- **Normative statement:** The event boundary shall schedule resumable processes against
  one simulation clock, resume them only when their requested event, timeout, or
  resource condition is satisfied, enforce exclusive capacity for one or more distinct
  slot resources, and surface unhandled process failure to the simulation caller.
- **Parents:** SYS-004
- **Acceptance criterion:** Under timeout, change, single-resource, and paired-resource
  contention over distinct resources, no process resumes before its trigger, capacity
  is never exceeded, a paired waiter retains no partial acquisition while blocked, and
  an unhandled process error reaches the caller.
- **Verification:** INTV-002 (test)
- **Context:** [Discrete events](../../context/core/discrete-events.md)

### Boundary semantics

- **Inputs:** A simulation clock, resumable process, event or timeout, and one or more
  distinct resource requests when multi-resource acquisition is requested.
- **Outputs:** A scheduled process result, resumption event, acquired resource set, or
  surfaced failure.
- **State:** The scheduler owns simulated time and process lifecycle; each exclusive
  resource tracks current ownership and waiters.
- **Errors:** Invalid process work or unhandled process exceptions are observable.
  Deadlock recovery and real-time scheduling guarantees are not specified.

## SUB-010 — Dispatch only through supported backend capabilities

- **Normative statement:** A numerical adapter shall declare or implement the
  capabilities needed to create, compose, transform, observe, measure, reduce, or
  evolve its native state, and the adapter boundary shall preserve representation-
  specific exact, stochastic, or compact-state semantics for supported requests. An
  external adapter shall participate through the same documented dispatch boundary
  without modifying core product source.
- **Parents:** SYS-001, SYS-003, SYS-007, SYS-009
- **Acceptance criterion:** Representative exact-state, trajectory, stabilizer, and
  Gaussian adapters return documented state manifolds, subsystem counts, and
  normalization or weight for every designated capability; requests outside the matrix
  do not report success; and an external adapter fixture is selected through the same
  boundary without changing a representation-independent baseline result.
- **Verification:** INTV-005 (test)
- **Context:** [Backend extension](../../context/simulation/backend-extension.md)

### Boundary semantics

- **Inputs:** Native state, selected subsystem positions, requested supported
  capability, and any symbolic object or background parameters required by that
  capability.
- **Outputs:** Updated or replacement native state, observable or measurement result,
  or an unsupported request.
- **State:** The adapter may mutate or replace native state according to its documented
  manifold; the register-state boundary remains responsible for logical ownership.
- **Errors:** Unsupported capability combinations do not have one standardized error
  type. No adapter-independent scientific-accuracy or performance budget is specified.
