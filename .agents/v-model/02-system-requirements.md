# System Requirements

These requirements specify observable capabilities and boundaries. Implementation
packages, files, and algorithms are intentionally excluded from their normative text.

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
- **Context:** [Backend support](../context/simulation/backend-support.md)

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
- **Context:** [Register model](../context/core/register-model.md)

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
- **Context:** [Time and noise](../context/simulation/time-and-noise.md)

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
- **Context:** [Discrete events](../context/core/discrete-events.md)

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
- **Context:** [Metadata and waits](../context/core/metadata-and-waits.md)

## SYS-006 — Transport delayed classical messages and quantum state

- **Normative statement:** The product shall provide directional delayed classical
  transport, explicit direct-versus-forwarded classical routing, per-location incoming
  message stores, and direct-link quantum transport that moves logical state ownership
  after configured delay and supported in-transit evolution.
- **Parents:** STK-001, STK-003
- **Acceptance criterion:** Given a three-location path with directional delays, direct
  classical and quantum deliveries arrive no earlier than their configured delays; a
  nonadjacent classical request reports no direct channel without forwarding and
  reaches the final incoming store with forwarding; quantum ownership moves to an
  empty destination without breaking a retained remote correlation; and a transmitted
  subsystem under a supported nontrivial channel background has the same joint
  observable as stationary evolution under that background for the same interval.
- **Verification:** SYSV-004 (test)
- **Context:** [Transport](../context/network/transport.md)

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
- **Context:** [Backend support](../context/simulation/backend-support.md)

## SYS-008 — Keep state, circuit, and protocol catalogs distinct and reusable

- **Normative statement:** The product shall provide distinct catalogs for
  parameterized resource-state models, immediate callable quantum routines, and
  resumable network-control protocols, so that each kind of building block can be used
  independently and composed through shared system interfaces.
- **Parents:** STK-003
- **Acceptance criterion:** Given one supported entry per catalog, the state entry
  initializes a resource, the circuit entry acts immediately on selected resources,
  and the protocol entry schedules as a resumable process, both independently and when
  composed in one scenario.
- **Verification:** SYSV-006 (test)
- **Context:** [State catalog](../context/zoos/states-catalog.md),
  [circuit catalog](../context/zoos/circuits-catalog.md), and
  [protocol catalog](../context/zoos/protocols-catalog.md)

## SYS-009 — Permit third-party use of documented extension seams

- **Normative statement:** The product shall permit external modules to provide new
  behavior at documented representation, operation, model-building, protocol, and
  optional-feature seams through the same dispatch and activation boundaries used by
  supported built-in behavior.
- **Parents:** STK-004
- **Acceptance criterion:** Given external fixtures for every representation,
  operation, model-building, protocol, and optional-feature extension class in the
  confirmed support inventory, normal product operations select each implementation
  and return its documented result without core-source changes.
- **Verification:** SYSV-007 (test)
- **Context:** [Backend extension](../context/simulation/backend-extension.md)

## SYS-010 — Provide structured diagnostics and optional inspection features

- **Normative statement:** The product shall emit structured simulation diagnostics
  with documented domain and event identifiers plus immutable primitive context, and
  shall make richer visualization and interactive inspection available when their
  declared optional capabilities are activated.
- **Parents:** STK-005
- **Acceptance criterion:** Representative diagnostics carry documented domain, event,
  simulation time, and process identity without retaining mutable simulation objects;
  each activated optional inspection entry point produces its documented result.
- **Verification:** SYSV-008 (test)
- **Context:** [Structured logging](../context/network/structured-logging.md)

## SYS-011 — Honor declared Julia compatibility without mandatory optional UI dependencies

- **Normative statement:** The core product shall load in a clean environment satisfying
  its declared Julia compatibility and required dependencies without requiring
  optional visualization, mapping, or interactive-inspection dependencies.
- **Parents:** STK-004, STK-005
- **Acceptance criterion:** In a clean compatible Julia environment with required
  dependencies present and optional UI dependencies absent, core loading succeeds and
  core operations remain available; loading each complete declared weak-dependency set
  activates only its corresponding extension.
- **Verification:** SYSV-008 (test)
- **Context:** [Optional extensions](../context/optional-extensions.md)

## SYS-012 — Repeat designated seeded workflows

- **Normative statement:** The product shall permit designated stochastic workflows
  that use Julia RNG state to be repeated under a fixed declared software environment,
  initial model, RNG seed, and scheduling configuration, without promising
  reproducibility for external services, unspecified threaded schedules, or monotonic
  storage identities.
- **Parents:** STK-005
- **Acceptance criterion:** Given a designated stochastic scenario whose random choices
  use Julia RNG state, a fixed software environment, initial model, and scheduling
  configuration, when two fresh runs reset that RNG state to the same seed, then
  selected scientific outcomes, simulated event times, and RNG-derived protocol
  identifiers agree. Internal monotonic storage identities are excluded unless their
  counters are reset.
- **Verification:** SYSV-009 (test)
- **Context:** [Testing workflow](../context/workflows/testing.md)

## SYS-013 — Inspect register and network structure and metadata

- **Normative statement:** The product shall expose nonmutating inspection of register
  assignment and numerical state plus indexed access to network registers, slots, and
  topology, and shall store and retrieve user metadata independently for vertices,
  undirected edges, and directed edges.
- **Parents:** STK-005
- **Acceptance criterion:** Given a network with multiple registers, an assigned shared
  state, vertex and undirected-edge metadata, and unequal metadata for opposing directed
  edges, public inspection reports assignment, shared ownership, and native state
  without mutation; graph and indexed queries reproduce the declared topology,
  registers, and slots; metadata values round-trip; undirected lookup is invariant to
  endpoint order while opposing directed values remain distinct; and bulk access or
  assignment covers the existing vertex or edge collection.
- **Verification:** SYSV-010 (test)
- **Context:** [Register model](../context/core/register-model.md) and
  [network topology and metadata](../context/network/topology-and-metadata.md)

## System-level limitations

The compatibility, failure-atomicity, Zoo-maturity, and budget limitations in the
[profile index](index.md) apply to every requirement.
