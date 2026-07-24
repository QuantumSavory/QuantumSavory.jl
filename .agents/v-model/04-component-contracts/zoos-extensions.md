# Zoo and Extension Component Contracts

## CMP-010 — Keep state-catalog parameters, expressions, and weights aligned

- **Normative statement:** A supported state-catalog type shall expose an ordered
  parameter tuple, one same-order exploratory range record per parameter, and a
  constructor accepting that tuple; every compatible expression shall have the
  declared subsystem arity, and its trace shall be one for a normalized model or the
  documented success weight for a weighted model.
- **Parents:** SUB-011
- **Acceptance criterion:** For every state type designated supported, when a value is
  constructed from the declared good parameter of every range record and expressed in
  every designated compatible representation, then construction succeeds, declared
  parameter and range names and order agree, subsystem arity is two, expression is
  nonzero, and symbolic and expressed traces agree with normalized or weighted
  semantics.
- **Verification:** UNITV-009 (test)
- **Origin / risk:** State catalog API and expression tests; maintainer confirmation
  pending; high normalization and parameter-mapping risk
- **Context:** [State catalog](../../context/zoos/states-catalog.md)

## CMP-011 — Keep supported circuits immediate and explicitly destructive

- **Normative statement:** A circuit type designated supported shall have one documented
  callable form, report its total required logical-slot arity, complete without a
  scheduling yield, and return all measurement or success information required by its
  caller while clearing every input documented as measured, sacrificial, or reset on
  failure.
- **Parents:** SUB-012
- **Acceptance criterion:** For every circuit type included in the confirmed support
  baseline, when its callable form is checked and then executed on a valid fixture,
  then reported arity equals the number of required slot arguments, execution advances
  no simulation time, return shape matches its documentation, every destructive input
  is unassigned, and every documented retained success output remains assigned; for a
  supported failure fixture, every output documented as reset is unassigned.
- **Verification:** UNITV-010 (test)
- **Origin / risk:** Circuit interfaces, docs, and tests; support-baseline confirmation
  pending; critical destructive-state risk
- **Context:** [Circuit catalog](../../context/zoos/circuits-catalog.md)

## CMP-012 — Revalidate protocol snapshots and preserve pair identity

- **Normative statement:** A protocol that retains a query snapshot across a scheduling
  yield or lock acquisition shall re-query the affected resources under all required
  locks before consuming or mutating them; reciprocal entangled resources shall carry
  matching pair identity, newly generated pairs shall use a fresh nonzero identity, and
  swaps shall derive the new reciprocal identity from both consumed pairs so delayed
  updates cannot target an unrelated current pair.
- **Parents:** SUB-013
- **Acceptance criterion:** Given reciprocal pairs, a swap or consume process, and an
  injected competing process that replaces one queried tag before lock acquisition,
  when both run, then the stale snapshot is not consumed as current and no unrelated
  state is mutated; given an uncontended swap, then both remote endpoints receive
  reciprocal metadata with the same identity derived from both consumed pair
  identities, and a delayed update carrying an old or mismatched identity is forwarded
  through matching history or rejected according to protocol policy rather than
  applied to the unrelated pair.
- **Verification:** UNITV-011 (test)
- **Origin / risk:** Race-aware protocol paths and entanglement identity behavior;
  maintainer confirmation pending; critical distributed-state risk
- **Context:** [Protocol development](../../context/network/protocol-development.md)

## CMP-013 — Keep log context primitive and optional activation isolated

- **Normative statement:** Common simulation log context shall contain simulated time
  and active process identity as primitive values, protocol context shall add protocol
  identity and an immutable ordered participant tuple, and an optional implementation
  shall add methods only after all dependencies declared for that capability are
  loaded.
- **Parents:** SUB-014
- **Acceptance criterion:** Given representative free-function and protocol log events,
  when their metadata is captured, then common fields have the documented primitive
  types, participant order is preserved, and no field retains a simulation, network,
  register, message, query, or protocol object; given optional dependencies absent,
  partially present, and fully present, then core loading succeeds in all cases and the
  optional implementation is selected only in the fully activated case.
- **Verification:** UNITV-012 (test)
- **Origin / risk:** Structured logging and extension activation behavior; maintainer
  confirmation pending; medium observability and loading risk
- **Context:** [Structured logging](../../context/network/structured-logging.md)

## Component limitations

- Explorer parameter ranges are descriptive metadata, not a promise of constructor
  validation.
- The supported circuit and advanced-protocol membership requires maintainer
  confirmation before baselining; known current behavior is not silently promoted.
- A compatibility parameter retained by a wrapped state model need not affect the
  underlying physical expression unless its support is explicitly confirmed.
- The combined pair-identity algebra can collide with its sentinel value; collision
  handling and any required bound are unresolved.
- Optional mapping can depend on external map services; availability and latency of
  those services are outside this contract.
