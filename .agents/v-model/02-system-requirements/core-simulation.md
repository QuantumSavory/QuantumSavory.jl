# Core and Simulation System Requirements

## SYS-001 — Lower symbolic descriptions into compatible representations

- **Normative statement:** The product shall accept supported symbolic states,
  operations, and observables and lower each one according to its requested use and the
  compatible numerical representation selected by the declared or default
  representation policy for the involved logical subsystems.
- **Parents:** STK-001, STK-002
- **Acceptance criterion:** Given a symbolic Bell state, supported two-body operation,
  and parity observable, when one fixture declares a compatible representation and
  another uses the compatible default, then initialization and operation complete and
  both parity results equal the expected deterministic value.
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

## SYS-003 — Advance monotonic local time and synchronize interactions

- **Normative statement:** The product shall track nondecreasing access time per logical
  subsystem, apply supported declared background evolution only when that subsystem
  advances, and synchronize interacting subsystems to one time no earlier than any
  participant's current local time.
- **Parents:** STK-001
- **Acceptance criterion:** Given assigned subsystems with different access times and
  supported backgrounds, advancing selected subsystems to a valid later target evolves
  each only for its elapsed interval and records the target without advancing an
  unselected subsystem; a later interaction synchronizes all participants at one
  common nondecreasing time.
- **Verification:** SYSV-002 (test)
- **Context:** [Time and noise](../../context/simulation/time-and-noise.md)

## SYS-004 — Coordinate event processes, waits, and exclusive resources

- **Normative statement:** The product shall support resumable processes driven by
  simulated events, timeouts, change waits, and exclusive resource reservations, with
  process failures observable to the simulation caller. Identical simulated timestamps
  shall not establish a public relative order between otherwise independent events or
  processes; required ordering shall be expressed through causal event or resource
  dependencies.
- **Parents:** STK-001, STK-003
- **Acceptance criterion:** Given two contenders for one-capacity resource, a timeout,
  and a delayed change, scheduling them never grants concurrent ownership, lets a
  blocked contender acquire only after the current owner releases, resumes the timeout
  no earlier than its scheduled simulated time, and wakes the waiter no earlier than
  the change; an unhandled process error reaches the simulation caller. Two independent
  actions at one timestamp have no specified relative order, while an explicit
  dependency orders dependent actions.
- **Verification:** SYSV-003 (test)
- **Context:** [Discrete events](../../context/core/discrete-events.md)

## SYS-005 — Store, query, consume, and revalidate metadata

- **Normative statement:** The product shall attach typed metadata to resource slots
  and message stores, query it by exact values, wildcards, or predicates in documented
  order, distinguish observation from consumption, and expose query results as
  snapshots rather than reservations. Public tag types and their field layouts shall
  remain compatible within a SemVer-compatible release series.
- **Parents:** STK-003
- **Acceptance criterion:** Given matching and nonmatching register and message-store
  entries, register exact, wildcard, predicate, first, all, FIFO/FILO, and consuming
  modes return documented results; message stores return the first FIFO match, support
  consumption, and reject the unsupported all-results mode; observation leaves the
  store unchanged, consumption removes only its result, and a snapshot held across a
  yield grants no reservation. A public-tag inventory matches its declared field types,
  order, and layout.
- **Verification:** SYSV-003 (test)
- **Context:** [Metadata and waits](../../context/core/metadata-and-waits.md)

## SYS-007 — Select and promote representations by capability

- **Normative statement:** When a register slot representation is omitted, the product
  shall use `QuantumOpticsRepr` for qubits and qumodes, treat `QuantumMCRepr` as a
  general peer, never select `CliffordRepr` or `GabsRepr` as an implicit slot default,
  and automatically promote constrained or mixed-representation state to a compatible
  more-general representation when the requested capability requires it.
  The product shall support explicitly requested general-to-specialized conversion
  through a configurable object describing the twirling and shall not specialize
  automatically. Representation-specific approximation controls shall be constructor
  arguments on the representation, and promotion shall use the selected target
  instance's configuration.
- **Parents:** STK-002
- **Acceptance criterion:** Registers with unspecified qubit or qumode representation
  select `QuantumOpticsRepr`. For every initialization, composition, operation,
  observable, measurement, traceout, background, non-instant evolution, and transport
  capability in the backend inventory, a supported request preserves its current
  representation; an unsupported constrained or mixed-representation request promotes
  to a supporting common representation using its configured approximation parameters
  and emits, once per call site, a warning naming only the initial and final
  representations. Supported Monte Carlo requests remain Monte Carlo. Given a
  supported general state, requested specialized representation, and configured
  twirling object, conversion produces that representation according to the object's
  declared semantics; without the object no specialization occurs. When no applicable
  implementation or promotion exists, Julia dispatch produces a `MethodError`,
  optionally augmented by an error hint.
- **Verification:** SYSV-005 (test)
- **Context:** [Backend support](../../context/simulation/backend-support.md)
