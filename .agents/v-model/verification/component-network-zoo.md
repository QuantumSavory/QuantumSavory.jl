# Network, Zoo, and Extension Component Verification

These focused actions check transport, catalog, protocol-identity, logging, and optional
activation invariants.

## UNITV-006 — Verify directional delays and explicit forwarding

- **Covers:** CMP-007
- **Method:** test
- **Procedure:** Configure unequal `A→B` and `B→A` delays on a three-location path, send
  direct messages both ways, then request `A→C` without and with forwarding.
- **Environment / configuration:** Root test environment with distinct per-direction
  times and a payload whose field order and values are discriminating.
- **Pass criterion:** Opposite direct arrivals differ by their configured delays; the
  unforwarded nonadjacent request reports no channel; the forwarded request reaches
  `C`, traverses only declared path edges, and retains the exact inner tag shape and
  values.
- **Status:** implemented
- **Evidence:** [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl)
- **Nonconformance:** No focused test distinguishes rejected direct delivery from
  explicit multi-hop forwarding while asserting every hop and the unchanged inner tag.

## UNITV-007 — Verify guarded quantum ownership transfer

- **Covers:** CMP-008
- **Method:** test
- **Procedure:** Send one half of a correlated state through a nonzero-delay direct
  channel with a supported background, inspect ownership before arrival, receive into
  an empty destination, then repeat with an assigned destination.
- **Environment / configuration:** Root tests with an assigned source whose access time
  is no later than arrival and explicit backreference identities.
- **Pass criterion:** From an assigned source whose access time is no later than
  modeled arrival, send unassigns the source and replaces it with exactly one in-transit
  owner in the shared mapping; at delayed arrival, receipt replaces that owner with the
  empty destination, leaves every reciprocal backreference consistent, and produces a
  joint observable equal to stationary evolution under the same background for the
  same interval. Receipt into an assigned destination reports failure before
  overwriting that destination.
- **Status:** implemented
- **Evidence:** [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** Tests do not assert the exact send/arrival times, the in-transit
  owner replacement, the pre-arrival destination, or every reciprocal backreference.
  Noise is checked only through selected end observables. Occupied receipt dequeues
  before checking vacancy, so recovery of the in-transit subsystem is not established;
  a source time later than arrival can fail after source ownership has moved.

## UNITV-009 — Verify StatesZoo parameter/expression alignment

- **Covers:** CMP-010
- **Method:** test
- **Procedure:** Enumerate every state type in the confirmed support baseline, construct
  it from each range record's declared good parameter, and express it in every
  designated compatible representation.
- **Environment / configuration:** Root test runner with ordered parameter/range,
  arity, nonzero-expression, and symbolic/native trace assertions.
- **Pass criterion:** Every construction succeeds; parameter and range names and order
  agree; arity is two; each expression is nonzero; and symbolic and expressed traces
  agree with the entry's normalized or documented weighted semantics in every
  designated representation.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`test_stateszoo_depolarized.jl`](../../../test/test_stateszoo_depolarized.jl)
- **Nonconformance:** Formula, range, representation, and normalization coverage is
  incomplete. The DepolarizedBellPair Clifford assertions are in
  `test/test_stateszoo_depolarized.jl`, whose name lacks `_tests` and is therefore
  excluded by `test/runtests.jl`.

## UNITV-010 — Verify immediate destructive circuit behavior

- **Covers:** CMP-011
- **Method:** test
- **Procedure:** For every circuit in the confirmed support baseline, check its callable
  form and reported arity, execute a valid success fixture while recording simulation
  time and all slots, then execute every documented reset-on-failure branch.
- **Environment / configuration:** Root test environment with deterministic outcomes
  where possible and before/after assignment snapshots.
- **Pass criterion:** Reported arity equals required slot arguments, execution advances
  no simulated time, and return shape matches documentation; every destructive input is
  unassigned, every documented retained success output stays assigned, and every
  output documented as reset is unassigned on the supported failure fixture.
- **Status:** implemented
- **Evidence:** [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), [`circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl), [`circuitzoo_superdense_tests.jl`](../../../test/general/circuitzoo_superdense_tests.jl), [`circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl)
- **Nonconformance:** No test asserts zero time advance or a complete per-circuit
  success/failure destruction matrix. `SDEncode`/`SDDecode` omit `inputqubits`;
  Stringent/Node arity, return, retained-output, and reset behavior is incomplete.

## UNITV-011 — Verify protocol snapshots and pair identity

- **Covers:** CMP-012
- **Method:** test
- **Procedure:** Generate a fresh pair, inject pre-lock replacement, run one uncontended
  swap from known IDs, and exercise live, history, delete-marker, stale-drop, and switch
  cleanup paths.
- **Environment / configuration:** Root test environment with deterministic pair IDs,
  recorded locks, reciprocal endpoint tags, history, delete markers, and ownership.
- **Pass criterion:** A generated pair gives both endpoints the same nonzero reciprocal
  ID. A stale snapshot is not consumed and mutates no unrelated state. An uncontended
  swap gives both remote endpoints reciprocal metadata with one ID equal to the
  combination of both consumed IDs. Each delayed update reaches matching live state,
  matching history, or its matching delete marker, or is logged and dropped as stale;
  it never mutates an unrelated live pair.
- **Status:** implemented
- **Evidence:** [`protocolzoo_entangler_tests.jl`](../../../test/general/protocolzoo_entangler_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl), [`protocolzoo_entanglement_counterpart_invariant_tests.jl`](../../../test/general/protocolzoo_entanglement_counterpart_invariant_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), [`protocolzoo_entanglement_consumer_stale_query_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_stale_query_tests.jl), [`protocolzoo_switch_stale_match_accounting_tests.jl`](../../../test/general/protocolzoo_switch_stale_match_accounting_tests.jl), [`protocolzoo_switch_stale_reciprocal_delete_tests.jl`](../../../test/general/protocolzoo_switch_stale_reciprocal_delete_tests.jl), [`protocolzoo_cutoff_cleanup_tests.jl`](../../../test/general/protocolzoo_cutoff_cleanup_tests.jl), [`myswapper_tutorial_tests.jl`](../../../test/examples/myswapper_tutorial_tests.jl)
- **Nonconformance:** No generated-pair test asserts reciprocal equal nonzero IDs, and
  no uncontended swap asserts both endpoint IDs equal the exact consumed-ID
  combination. Stale/update routes remain split across fixtures.

## UNITV-012 — Verify primitive log contexts and optional activation

- **Covers:** CMP-013
- **Method:** test
- **Procedure:** Capture representative free-function and protocol logs, then load
  isolated environments with optional dependencies absent, partially present, and fully
  present for each declared extension.
- **Environment / configuration:** Core and temporary extension projects plus
  configured plotting backends.
- **Pass criterion:** Common log fields have documented primitive types, participant
  order is preserved, and no field retains a simulation, network, register, message,
  query, or protocol object. Core loading succeeds in every dependency state, and an
  optional implementation is selected only when its complete declared set is present.
- **Status:** implemented
- **Evidence:** [`Project.toml`](../../../Project.toml), [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl)
- **Nonconformance:** Logging tests sample contexts rather than checking every excluded
  mutable object type; no clean absent/partial/full activation matrix exists.
