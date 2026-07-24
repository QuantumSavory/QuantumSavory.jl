# Zoo and Extension Contracts

## SUB-011 — Provide parameterized state-model catalog entries

- **Normative statement:** A supported state-catalog entry shall expose a stable
  parameter order and exploratory ranges, lower to every representation designated
  compatible for that entry, and distinguish normalized state models from weighted
  models whose trace carries a documented success weight. An external state-model type
  shall participate through the same construction and lowering dispatch without core
  source changes.
- **Parents:** SYS-008, SYS-009
- **Acceptance criterion:** Given one normalized and one weighted supported state entry,
  when each is constructed from its declared parameter order and lowered to each
  designated compatible representation, then subsystem arity is correct, the
  normalized entry has unit trace, the weighted entry's trace equals its documented
  success weight, and explorer metadata reports one range record per declared
  parameter in the same order. An external fixture is selected through the same state
  boundary without changing a built-in baseline result.
- **Verification:** INTV-006 (test)
- **Origin / risk:** Current state catalog and explorer interface; maintainer
  confirmation pending; high normalization-interpretation risk
- **Context:** [State catalog](../../context/zoos/states-catalog.md)

### Boundary semantics

- **Inputs:** A supported state entry type and its ordered physical/model parameters.
- **Outputs:** A symbolic state model, optional explorer parameter metadata, and a
  compatible native expression.
- **State:** Catalog entries are value descriptions and do not assign register state
  until passed to the register boundary.
- **Errors:** Declared ranges are descriptive explorer metadata, not a general promise
  of constructor validation. Unsupported representation lowering reports failure.

## SUB-012 — Provide immediate callable circuit entries

- **Normative statement:** A circuit entry designated supported shall run immediately
  on caller-selected logical slots without scheduling waits or message exchange, shall
  expose its required input arity, and shall document its return value and destructive
  measurement or removal effects. An external circuit type shall participate through
  the same callable and arity dispatch without core source changes.
- **Parents:** SYS-008, SYS-009
- **Acceptance criterion:** Given supported swap, purification, encoding/decoding, and
  fusion fixtures with the documented number of assigned input slots, when each circuit
  reports its arity and is called, then reported arity equals the required slot
  arguments, it returns its documented outcome shape, performs no simulated wait,
  removes every sacrificial or measured input documented as destructive, and preserves
  every retained output documented for its success branch. An external fixture is
  selected through the same boundaries without changing a built-in baseline result.
- **Verification:** INTV-006 (test)
- **Origin / risk:** Current circuit catalog and tests; maintainer confirmation pending;
  high destructive-state risk
- **Context:** [Circuit catalog](../../context/zoos/circuits-catalog.md)

### Boundary semantics

- **Inputs:** A circuit value, its configuration, and already selected logical slots.
- **Outputs:** Immediate state mutation plus documented measurement, bit tuple, or
  success result.
- **State:** Destructive measurements and failed purification may unassign inputs as
  documented by the supported entry.
- **Errors:** Invalid configuration or arity reports failure. Which complex
  purification families are mature enough for the supported baseline remains
  unresolved.

## SUB-013 — Compose resumable protocols through shared control interfaces

- **Normative statement:** A protocol entry designated supported shall execute as a
  resumable process, coordinate through common metadata, messaging, timing, and
  resource-reservation boundaries, and revalidate mutable resource snapshots after
  scheduling yields before consuming them. An entry that manages reciprocal
  entanglement shall also preserve pair identity across updates. An external protocol
  type shall participate through the same resumable-process dispatch without core
  source changes.
- **Parents:** SYS-004, SYS-005, SYS-008, SYS-009
- **Acceptance criterion:** Given an entanglement producer, tracker, swapper, consumer,
  and delayed competing mutation, when the protocols run concurrently, then generated
  pairs have reciprocal identity-bearing metadata, delayed updates are applied only to
  the matching current or documented historical pair, a snapshot invalidated before
  lock acquisition is not consumed as current, and successfully consumed resources are
  removed exactly once. An external fixture schedules through the same process boundary
  without changing a built-in baseline result.
- **Verification:** INTV-003 (test), INTV-007 (test)
- **Origin / risk:** Core protocol behavior and race-aware tests; maintainer
  confirmation pending; high distributed-consistency risk
- **Context:** [Protocol catalog](../../context/zoos/protocols-catalog.md)

### Boundary semantics

- **Inputs:** A simulation domain, network, participating locations, protocol
  configuration, and shared tags or messages.
- **Outputs:** A resumable process and protocol-specific resource, metadata, message, or
  measurement effects.
- **State:** Protocol state spans process lifecycle, reserved slots, metadata snapshots,
  messages, and pair identities. Snapshot data is not a reservation.
- **Errors:** Exhausted attempts, stale updates, unavailable resources, and unsupported
  topology follow the selected protocol's documented policy. Maturity and
  cross-release stability of advanced protocol families remain unresolved.

## SUB-014 — Activate optional inspection and structured logging without coupling core load

- **Normative statement:** The optional-extension and logging boundary shall keep core
  loading independent of optional UI capabilities, activate an optional implementation
  only when its declared dependencies are present, and emit structured diagnostics
  whose common context contains immutable primitive simulation and protocol identity
  fields. Optional methods shall be addable at the declared activation boundary without
  modifying core product source or changing core-only results.
- **Parents:** SYS-009, SYS-010, SYS-011
- **Acceptance criterion:** Given one core-only environment and environments activating
  each declared optional capability, when the product is loaded and corresponding
  entry points are called, then core loading succeeds without optional dependencies,
  partial dependency sets do not activate an incomplete extension, activated calls
  dispatch to the optional implementation, and representative diagnostics contain
  the documented domain, event, simulation time, process identity, protocol identity,
  and ordered participant identifiers without retaining mutable product objects. A
  core-only baseline result is unchanged after optional activation.
- **Verification:** INTV-008 (test)
- **Origin / risk:** Optional activation and logging schema; maintainer confirmation
  pending; medium installation and observability risk
- **Context:** [Optional extensions](../../context/optional-extensions.md)

### Boundary semantics

- **Inputs:** Core or optional entry-point call, activated dependency set, and
  diagnostic event context.
- **Outputs:** Core result, activated optional result, unavailable method boundary, or
  structured log record.
- **State:** Optional activation extends dispatch without changing stored simulation
  state; log context is a snapshot of primitive values.
- **Errors:** Optional capability absence is not a core-load failure. External network
  availability for map-backed visualization and visualization update cadence are not
  specified here.
