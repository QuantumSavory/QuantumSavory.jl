# Zoo and Extension Contracts

## SUB-011 — Provide parameterized state-model catalog entries

- **Normative statement:** Every exported normalized or weighted state-catalog entry
  shall be supported, document its constructor parameters and compatible
  representations, expose introspection of expected parameter values, and distinguish
  unit-trace models from weighted models whose trace carries a documented success
  weight. Constructor parameters, not concrete struct fields, form the public
  interface.
- **Parents:** SYS-007, SYS-008, SYS-009, SYS-012
- **Acceptance criterion:** For every exported state entry, generated API and example
  documentation names every constructor parameter, introspection returns an expected
  value or exploratory range for each parameter in constructor order, and lowering to
  every representation designated compatible produces the declared subsystem arity.
  Normalized entries have unit trace and weighted entries have trace equal to their
  documented success weight; concrete field layout is not required by the public
  checks.
- **Verification:** INTV-006 (test)
- **Origin / risk:** Current state catalog, explorer interface, and maintainer
  interview; high normalization-interpretation risk
- **Context:** [State catalog](../../context/zoos/states-catalog.md)

### Boundary semantics

- **Inputs:** A supported state entry type and its ordered physical/model parameters.
- **Outputs:** A symbolic state model, optional explorer parameter metadata, and a
  compatible native expression.
- **State:** Catalog entries are value descriptions and do not assign register state
  until passed to the register boundary.
- **Errors:** Expected-value or range metadata is descriptive, not a general constructor
  validation promise. If neither the selected representation nor a permitted promotion
  supports lowering, dispatch produces a `MethodError`.

## SUB-012 — Provide immediate callable circuit entries

- **Normative statement:** Every public circuit entry shall be supported, run
  immediately on caller-selected logical slots without scheduling waits or message
  exchange, and expose a consistent public feature API describing at least required
  input arity, return behavior, and destructive measurement or removal effects.
- **Parents:** SYS-008, SYS-009, SYS-012
- **Acceptance criterion:** For every public swap, purification (including advanced
  families), encoding/decoding, and fusion circuit, generated API and example
  documentation agrees with feature introspection. On a valid fixture, reported arity
  equals required slot arguments, the result has its documented shape, execution
  performs no simulated wait, every documented destructive input is removed, and every
  documented retained success output remains. Internal helper circuits are absent from
  public discovery.
- **Verification:** INTV-006 (test)
- **Origin / risk:** Current circuit catalog, tests, and maintainer interview; high
  destructive-state risk
- **Context:** [Circuit catalog](../../context/zoos/circuits-catalog.md)

### Boundary semantics

- **Inputs:** A circuit value, its configuration, and already selected logical slots.
- **Outputs:** Immediate state mutation plus documented measurement, bit tuple, or
  success result.
- **State:** Destructive measurements and failed purification may unassign inputs as
  documented by the supported entry.
- **Errors:** Invalid configuration or arity reports failure. No consistency guarantee
  applies after an exception.

## SUB-013 — Compose resumable protocols through shared control interfaces

- **Normative statement:** Every public protocol entry, including core entanglement,
  switch, QTCP, and MBQC families, shall be supported as a resumable process, document
  every constructor parameter, coordinate through common metadata, messaging, timing,
  and resource-reservation boundaries, and revalidate mutable resource snapshots after
  scheduling yields before consuming them. Constructor parameters, not concrete struct
  fields, form the public interface.
- **Parents:** SYS-004, SYS-005, SYS-008, SYS-009, SYS-012
- **Acceptance criterion:** The public protocol inventory includes core entanglement,
  switch, QTCP, and MBQC families, with every constructor parameter present in
  generated API documentation and an applicable example. Representative entries
  schedule through the shared process boundary. Given an entanglement producer,
  tracker, swapper, consumer, and delayed competing mutation, generated pairs have
  reciprocal identity-bearing metadata, delayed updates target only the matching
  current or documented historical pair, a snapshot invalidated before lock
  acquisition is not consumed as current, and successfully consumed resources are
  removed exactly once.
- **Verification:** INTV-003 (test), INTV-007 (test)
- **Origin / risk:** Core protocol behavior, race-aware tests, and maintainer interview;
  high distributed-consistency risk
- **Context:** [Protocol catalog](../../context/zoos/protocols-catalog.md)

### Boundary semantics

- **Inputs:** A simulation domain, network, participating locations, protocol
  configuration, and shared tags or messages.
- **Outputs:** A resumable process and protocol-specific resource, metadata, message, or
  measurement effects.
- **State:** Protocol state spans process lifecycle, reserved slots, metadata snapshots,
  messages, and pair identities. Snapshot data is not a reservation.
- **Errors:** Exhausted attempts, stale updates, unavailable resources, and unsupported
  topology follow the selected protocol's documented policy. An exception ends the
  affected run without a post-exception consistency guarantee.

## SUB-014 — Activate optional inspection and structured logging without coupling core load

- **Normative statement:** The optional-extension and logging boundary shall keep core
  loading independent of optional UI capabilities, activate an optional implementation
  only when its complete declared dependency set is present, render successfully
  through supported built-in optional entry points, and emit structured diagnostics
  under stable documented log groups. Log payload and rendering content are
  noncontractual.
- **Parents:** SYS-009, SYS-010, SYS-011
- **Acceptance criterion:** Given one core-only environment and environments activating
  each declared optional capability, when the product is loaded and corresponding
  entry points are called, then core loading succeeds without optional dependencies,
  partial dependency sets do not activate an incomplete extension, activated calls
  dispatch to the built-in optional implementation and render successfully, and
  representative diagnostics are selectable through every documented log group. When
  an optional integration uses an external service, the call succeeds against an
  available test service. Exact log payload and rendering content are not compared.
- **Verification:** INTV-008 (test)
- **Origin / risk:** Optional activation, log groups, and maintainer interview; medium
  installation and observability risk
- **Context:** [Optional extensions](../../context/optional-extensions.md)

### Boundary semantics

- **Inputs:** Core or optional entry-point call, activated dependency set, and
  diagnostic event context.
- **Outputs:** Core result, successful optional rendering, unavailable method boundary,
  or structured log record in a documented group.
- **State:** Optional activation extends dispatch without changing stored simulation
  state; log payload shape is not a stable interface.
- **Errors:** Optional capability absence is not a core-load failure. External network
  availability, latency, and long-term service behavior are outside this contract, but
  integration behavior is supported when the service is available.
