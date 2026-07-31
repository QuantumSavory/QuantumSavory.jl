# Zoo and Extension Component Contracts

## CMP-010 — Keep state-catalog parameters, expressions, and weights aligned

- **Normative statement:** Every public normalized or weighted state-catalog type
  shall expose a constructor-ordered parameter description and expected-value
  introspection without making its concrete field layout public; every designated
  compatible representation shall produce the declared subsystem arity, and trace
  shall be one for a normalized model or the documented success weight for a weighted
  model.
- **Parents:** SUB-011
- **Acceptance criterion:** For every public state type, when a value is constructed
  from each introspected expected parameter value and expressed in every representation
  that entry designates compatible, then construction succeeds, constructor parameter
  names and order agree with introspection and generated documentation, subsystem arity
  equals the entry's declaration, expression is nonzero, and symbolic and expressed
  traces agree with normalized or weighted semantics. No check depends on concrete
  struct field names.
- **Verification:** UNITV-009 (test)
- **Origin / risk:** State catalog API, expression tests, and maintainer interview; high
  normalization and parameter-mapping risk
- **Context:** [State catalog](../../context/zoos/states-catalog.md)

## CMP-011 — Keep supported circuits immediate and explicitly destructive

- **Normative statement:** Every public circuit type shall expose a consistent
  documented feature interface and callable form that reports total required
  logical-slot arity, return behavior, and destructive effects, completes without a
  scheduling yield, and clears every input documented as measured, sacrificial, or
  reset on a returned failure branch.
- **Parents:** SUB-012
- **Acceptance criterion:** For every public swap, purification (including Stringent
  and Expedient families), encoding/decoding, and fusion circuit, feature introspection,
  generated documentation, and the callable form agree. On a valid fixture, reported
  arity equals required slot arguments, execution advances no simulation time, return
  shape matches documentation, every destructive input is unassigned, and every
  documented retained success output remains assigned; on a documented returned
  failure branch, every output documented as reset is unassigned.
- **Verification:** UNITV-010 (test)
- **Origin / risk:** Circuit interfaces, docs, tests, and maintainer interview; critical
  destructive-state risk
- **Context:** [Circuit catalog](../../context/zoos/circuits-catalog.md)

## CMP-012 — Revalidate protocol snapshots and preserve pair identity

- **Normative statement:** A supported protocol that retains a query snapshot across a
  scheduling yield or lock acquisition shall re-query the affected resources under all
  required locks before consuming or mutating them; supported entanglement-lifecycle
  protocols shall give reciprocal resources matching pair identity, use fresh nonzero
  identity for generated pairs, and derive swap identity from both consumed pairs so
  delayed updates cannot target an unrelated current pair.
- **Parents:** SUB-013
- **Acceptance criterion:** Given reciprocal pairs, a swap or consume process, and an
  injected competing process that replaces one queried tag before lock acquisition,
  when both run, then the stale snapshot is not consumed as current and no unrelated
  state is mutated; given generation of a fresh pair, both endpoints receive the same
  nonzero fresh identity; given an uncontended swap, both remote endpoints receive
  reciprocal metadata with the same identity derived from both consumed pair
  identities. A delayed update is applied to a matching live pair, forwarded through
  matching history, used to advance a matching delete marker, or logged and dropped as
  stale; it never mutates an unrelated live pair.
- **Verification:** UNITV-011 (test)
- **Origin / risk:** Race-aware protocol paths, entanglement identity behavior, and
  maintainer interview; critical distributed-state risk
- **Context:** [Protocol development](../../context/network/protocol-development.md)

## CMP-013 — Preserve log groups and isolate optional activation

- **Normative statement:** Public log-group identifiers shall remain compatible within
  a SemVer-compatible release series, while individual events, payload fields,
  messages, ordering, and record sequences may change. A built-in optional
  implementation shall activate only after all dependencies declared for that
  capability are loaded and shall render successfully when any required external
  integration is available.
- **Parents:** SUB-014
- **Acceptance criterion:** Given representative core and protocol activity, emitted
  records are selectable under every documented public log group without asserting
  payload fields or event identifiers. Given optional dependencies absent, partially
  present, and fully present, core loading succeeds in all cases, the optional
  implementation is selected only in the fully activated case, and every public
  renderer completes against available dependencies or test services without an exact
  content comparison.
- **Verification:** UNITV-012 (test)
- **Origin / risk:** Structured logging, built-in optional activation, and maintainer
  interview; medium observability and loading risk
- **Context:** [Structured logging](../../context/network/structured-logging.md)

## Component limitations

- Explorer parameter ranges are descriptive metadata, not a promise of constructor
  validation.
- All public Zoo entries are supported. Current missing documentation, state
  introspection gaps, circuit arity/return/cleanup inconsistencies, and incomplete QTCP
  or MBQC paths remain nonconformances rather than experimental exclusions.
- Internal Zoo helpers and tutorial-local helpers are not public.
- The Genqo wrappers currently accept a documented `Pᵈ` parameter that does not affect
  their physical expression; this is a visible implementation gap, not a general
  waiver for public constructor behavior.
- The combined pair-identity algebra can collide with its sentinel value; this is a
  current protocol defect, not an experimental-support exclusion.
- Optional mapping can depend on external map services; availability and latency of
  those services are outside this contract, while integration behavior is supported
  when a service is available.
- Exceptions provide no Zoo-level rollback or post-exception consistency guarantee.
