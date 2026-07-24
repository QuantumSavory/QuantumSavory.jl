# Zoo, Extension, and Observability System Requirements

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
- **Context:** [State catalog](../../context/zoos/states-catalog.md),
  [circuit catalog](../../context/zoos/circuits-catalog.md), and
  [protocol catalog](../../context/zoos/protocols-catalog.md)

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
- **Context:** [Backend extension](../../context/simulation/backend-extension.md)

## SYS-010 — Provide structured diagnostics and optional inspection features

- **Normative statement:** The product shall emit structured simulation diagnostics
  with documented domain and event identifiers plus immutable primitive context, and
  shall make richer visualization and interactive inspection available when their
  declared optional capabilities are activated.
- **Parents:** STK-005
- **Acceptance criterion:** Representative diagnostics carry documented domain, event,
  simulation time, and process identity as immutable primitive values without retaining
  mutable simulation objects; each activated optional inspection entry point produces
  its documented result.
- **Verification:** SYSV-008 (test)
- **Context:** [Structured logging](../../context/network/structured-logging.md)

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
- **Context:** [Optional extensions](../../context/optional-extensions.md)

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
- **Context:** [Testing workflow](../../context/workflows/testing.md)
