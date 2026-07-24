# Core and Simulation System Requirements

## SYS-001 — Lower symbolic descriptions into compatible representations

- **Normative statement:** The product shall accept supported symbolic states,
  operations, and observables and lower each one according to its requested use and the
  compatible numerical representation selected for the involved logical subsystems.
- **Parents:** STK-001, STK-002
- **Acceptance criterion:** Given a symbolic Bell state, supported two-body operation,
  and parity observable, when the scenario uses two compatible representations, then
  initialization and operation complete and both parity results equal the expected
  deterministic value.
- **Verification:** SYSV-001 (test)
- **Context:** [Backend support](../../context/simulation/backend-support.md)

## SYS-002 — Represent heterogeneous registers with factorized state ownership

- **Normative statement:** The product shall represent a register as logical subsystem
  slots with independently declared subsystem traits, preferred representations,
  background models, assignment state, and access time, while retaining explicitly
  factorized state ownership until an interaction requires composition.
- **Parents:** STK-001, STK-002
- **Acceptance criterion:** Given slots with distinct declarations and an explicitly
  factorized symbolic state, initialization leaves each declaration observable and
  each factor separately owned; a supported coupling later makes only its touched
  factors share composed ownership.
- **Verification:** SYSV-001 (test)
- **Context:** [Register model](../../context/core/register-model.md)

## SYS-003 — Advance time and background evolution on demand without rewind

- **Normative statement:** The product shall track access time per logical subsystem,
  apply supported declared background evolution when an operation or synchronization
  advances that subsystem, and reject an operation requested before the subsystem's
  current access time.
- **Parents:** STK-001
- **Acceptance criterion:** Given assigned subsystems with different access times and
  supported backgrounds, advancing to a later target evolves each selected subsystem
  only for its elapsed interval and records the target; requesting an earlier time
  reports an error.
- **Verification:** SYSV-002 (test)
- **Context:** [Time and noise](../../context/simulation/time-and-noise.md)

## SYS-004 — Coordinate event processes, waits, and exclusive resources

- **Normative statement:** The product shall support resumable processes driven by
  simulated events, timeouts, change waits, and exclusive resource reservations, with
  process failures observable to the simulation caller.
- **Parents:** STK-001, STK-003
- **Acceptance criterion:** Given two contenders for one-capacity resource and a
  delayed change, scheduling them never grants concurrent ownership, resumes the second
  contender only after release, and wakes the change waiter no earlier than the change;
  an unhandled process error reaches the simulation caller.
- **Verification:** SYSV-003 (test)
- **Context:** [Discrete events](../../context/core/discrete-events.md)

## SYS-005 — Store, query, consume, and revalidate metadata

- **Normative statement:** The product shall attach typed metadata to resource slots
  and message stores, query it by exact values, wildcards, or predicates in documented
  order, distinguish observation from consumption, and expose query results as
  snapshots rather than reservations.
- **Parents:** STK-003
- **Acceptance criterion:** Given matching and nonmatching register and message-store
  entries, register exact, wildcard, predicate, first, all, FIFO/FILO, and consuming
  modes return documented results; message stores return the first FIFO match, support
  consumption, and reject the unsupported all-results mode; observation leaves the
  store unchanged, consumption removes only its result, and a snapshot held across a
  yield grants no reservation.
- **Verification:** SYSV-003 (test)
- **Context:** [Metadata and waits](../../context/core/metadata-and-waits.md)

## SYS-007 — Expose explicit backend capability boundaries

- **Normative statement:** The product shall execute a state, operation, observable,
  measurement, background, or non-instant evolution only through a numerical
  representation that supports that requested capability, and shall not report an
  unsupported combination as successful by silently changing its physical meaning.
- **Parents:** STK-002
- **Acceptance criterion:** For every state, operation, observable, measurement,
  background, and non-instant capability cell in the confirmed backend support
  inventory, a supported fixture produces its documented result and a designated
  unsupported fixture does not report success or silently change physical meaning.
- **Verification:** SYSV-005 (test)
- **Context:** [Backend support](../../context/simulation/backend-support.md)
