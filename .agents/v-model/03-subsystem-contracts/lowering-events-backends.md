# Symbolic Lowering, Event, and Backend Contracts

## SUB-001 — Preserve the symbolic-to-representation boundary

- **Normative statement:** The symbolic boundary shall combine a supported symbolic
  description, its intended use as state, operation, or observable, and the involved
  subsystem representation policy to produce a semantically corresponding native
  object through a representation supporting the requested capability.
- **Parents:** SYS-001, SYS-007
- **Acceptance criterion:** Given supported symbolic state, operation, and observable
  fixtures, lowering for two compatible representations produces native objects with
  the expected preparation, operation effect, and observable result; an unsupported
  constrained representation is promoted according to the representation policy, and
  a request with no applicable lowering or promotion produces a `MethodError`.
- **Verification:** INTV-001 (test)
- **Context:** [Backend support](../../context/simulation/backend-support.md)

### Boundary semantics

- **Inputs:** A supported symbolic description, intended use, involved subsystem traits,
  and declared or default representation policy.
- **Outputs:** A native state, operation, or observable compatible with the selected
  representation.
- **State:** Lowering itself does not assign or mutate logical subsystem ownership;
  the consuming operation owns that mutation.
- **Errors:** A request with no applicable implementation or promotion uses Julia's
  `MethodError`; an error hint may add contextual guidance.

## SUB-004 — Schedule resumable events and exclusive resources

- **Normative statement:** The event boundary shall schedule resumable processes against
  one simulation clock, resume them only when their requested event, timeout, or
  resource condition is satisfied, enforce exclusive capacity for one or more distinct
  slot resources, and surface unhandled process failure to the simulation caller.
  Equal timestamps alone shall not order independent resumptions; any required order
  shall follow an explicit causal dependency.
- **Parents:** SYS-004
- **Acceptance criterion:** Under timeout, change, single-resource, and paired-resource
  contention over distinct resources, no process resumes before its trigger, capacity
  is never exceeded, a paired waiter retains no partial acquisition while blocked, and
  an unhandled process error reaches the caller. No result depends on tie-breaking
  between independent equal-time events, while an explicit dependency is respected.
- **Verification:** INTV-002 (test)
- **Context:** [Discrete events](../../context/core/discrete-events.md)

### Boundary semantics

- **Inputs:** A simulation clock, resumable process, event or timeout, and one or more
  distinct resource requests when multi-resource acquisition is requested.
- **Outputs:** A scheduled process result, resumption event, acquired resource set, or
  surfaced failure.
- **State:** The scheduler owns simulated time and process lifecycle; each exclusive
  resource tracks current ownership and waiters. ConcurrentSim's equal-time
  tie-breaking is an internal implementation choice.
- **Errors:** Invalid process work or unhandled process exceptions are observable.
  Deadlock recovery and real-time scheduling guarantees are not specified.

## SUB-010 — Dispatch and promote through supported backend capabilities

- **Normative statement:** The documented numerical-adapter interface shall support
  repository and external-library implementations of the capabilities needed to
  create, compose, transform, observe, measure, reduce, or evolve native state. The
  coordination boundary shall preserve a supporting current representation,
  automatically promote an insufficient constrained or mixed set to a configured common
  general representation, and perform requested general-to-specialized conversion
  through an explicit configurable object describing the twirling.
- **Parents:** SYS-001, SYS-003, SYS-007, SYS-009
- **Acceptance criterion:** Representative exact-state, trajectory, stabilizer, and
  Gaussian adapters return documented state manifolds, subsystem counts, and
  normalization or weight for every designated capability. `QuantumOpticsRepr` and
  `QuantumMCRepr` remain general peers for supported requests; insufficient stabilizer,
  Gaussian, or mixed representations promote for every capability class using the
  target representation's configured approximation parameters and warn once per call
  site with the initial and final representations. Given a supported general input and
  requested specialized representation, an explicit twirling object produces that
  representation with the object's declared semantics; without the object no
  specialization occurs. A separately supplied minimal adapter participates through the
  same documented register and lowering generics without repository-private hooks. A
  request with no applicable implementation or promotion produces a `MethodError`.
- **Verification:** INTV-005 (test)
- **Context:** [Backend extension](../../context/simulation/backend-extension.md)

### Boundary semantics

- **Inputs:** Native state, selected subsystem positions, requested capability,
  representation instance with constructor-configured approximation parameters,
  optional explicit twirling object, and any symbolic object or background parameters
  required by the capability.
- **Outputs:** Updated or replacement native state, observable or measurement result,
  or an unsupported request.
- **State:** The adapter may mutate or replace native state according to its documented
  manifold; the register-state boundary remains responsible for logical ownership.
- **Errors:** Unsupported dispatch produces a `MethodError`; error hints may explain
  relevant capability or promotion information. No adapter-independent scientific-
  accuracy or performance budget is specified.
