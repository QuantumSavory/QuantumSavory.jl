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
  an empty destination, then repeat with an assigned destination and capture warnings.
- **Environment / configuration:** Root tests with an assigned source whose access time
  is no later than arrival and explicit backreference identities.
- **Pass criterion:** From an assigned source whose access time is no later than
  modeled arrival, send unassigns the source and replaces it with exactly one in-transit
  owner in the shared mapping; at delayed arrival, receipt replaces that owner with the
  empty destination, leaves every reciprocal backreference consistent, and produces a
  joint observable equal to stationary evolution under the same background for the
  same interval. Receipt into an assigned destination reports failure, discards the
  transmitted state, and emits a warning; no recovery or other post-exception
  simulation-state condition is asserted.
- **Status:** implemented
- **Evidence:** [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** Tests do not assert the exact send/arrival times, the in-transit
  owner replacement, the pre-arrival destination, or every reciprocal backreference.
  Noise is checked only through selected end observables. Occupied receipt does discard
  the dequeued subsystem but emits no warning.

## UNITV-009 — Verify StatesZoo parameter/expression alignment

- **Covers:** CMP-010
- **Method:** test
- **Procedure:** Enumerate every public state type from generated docs and
  `export`/`public` declarations,
  construct it from each expected-value introspection record, and express it in every
  representation documented for that entry.
- **Environment / configuration:** Root test runner with constructor/introspection
  order, declared arity, nonzero-expression, and symbolic/native trace assertions.
- **Pass criterion:** Every public normalized or weighted state has API and
  example documentation; its documented constructor parameters and expected-value
  introspection names/order agree; every declared-good construction succeeds; declared
  arity and expression are correct; and symbolic and expressed traces agree with its
  normalized or documented weighted semantics in every designated representation.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`test_stateszoo_depolarized.jl`](../../../test/test_stateszoo_depolarized.jl)
- **Nonconformance:** Public inventory, constructor docs, examples, expected-value
  introspection, representation, and normalization coverage is incomplete.
  `BarrettKokBellPair` omits its documented `m` parameter from introspection, and
  weighted convenience constructors lack parameter prose. The DepolarizedBellPair
  Clifford assertions are in
  `test/test_stateszoo_depolarized.jl`, whose name lacks `_tests` and is therefore
  excluded by `test/runtests.jl`.

## UNITV-010 — Verify immediate destructive circuit behavior

- **Covers:** CMP-011
- **Method:** test
- **Procedure:** Enumerate every public basic and advanced circuit from generated docs;
  check its callable form and public feature introspection, execute a valid success
  fixture while recording simulation time and slots, then execute every documented
  non-exceptional reset-on-failure branch.
- **Environment / configuration:** Root test environment with deterministic outcomes
  where possible and before/after assignment snapshots.
- **Pass criterion:** Every public circuit has API and user-example documentation.
  Its feature introspection reports the required arity and other documented features
  consistently; execution advances no simulated time and returns the documented shape;
  every destructive input is unassigned, every documented retained success output stays
  assigned, and every output documented as reset is unassigned on its supported
  non-exceptional failure fixture. Internal helper circuits are absent from the public
  inventory.
- **Status:** implemented
- **Evidence:** [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), [`circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl), [`circuitzoo_superdense_tests.jl`](../../../test/general/circuitzoo_superdense_tests.jl), [`circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl)
- **Nonconformance:** No test derives the public inventory, checks documentation and
  examples, asserts zero time advance, or covers the complete feature/destruction
  matrix. `SDEncode`/`SDDecode` omit `inputqubits`; Stringent/Expedient/Node arity,
  return, retained-output, and reset behavior is incomplete.

## UNITV-011 — Verify protocol snapshots and pair identity

- **Covers:** CMP-012
- **Method:** test
- **Procedure:** Run core, Switch, QTCP, and MBQC protocols under documented valid
  concurrency; generate a fresh pair, inject pre-lock replacement, run one uncontended
  swap from known IDs, and exercise live, history, delete-marker, stale-drop, and switch
  cleanup paths.
- **Environment / configuration:** Root test environment with deterministic pair IDs,
  recorded locks, reciprocal endpoint tags, history, delete markers, and ownership.
- **Pass criterion:** Under documented valid usage, every protocol family locks and
  revalidates retained query snapshots before destructive mutation; no resource is
  consumed twice and unrelated resources are untouched. A generated pair gives both
  endpoints the same nonzero reciprocal ID. An uncontended swap gives both remote
  endpoints reciprocal metadata with one ID equal to the combination of both consumed
  IDs. Each delayed update reaches matching live state, history, or delete marker, or is
  logged and dropped as stale; it never mutates an unrelated live pair.
- **Status:** implemented
- **Evidence:** [`protocolzoo_entangler_tests.jl`](../../../test/general/protocolzoo_entangler_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl), [`protocolzoo_entanglement_counterpart_invariant_tests.jl`](../../../test/general/protocolzoo_entanglement_counterpart_invariant_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), [`protocolzoo_entanglement_consumer_stale_query_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_stale_query_tests.jl), [`protocolzoo_switch_stale_match_accounting_tests.jl`](../../../test/general/protocolzoo_switch_stale_match_accounting_tests.jl), [`protocolzoo_switch_stale_reciprocal_delete_tests.jl`](../../../test/general/protocolzoo_switch_stale_reciprocal_delete_tests.jl), [`protocolzoo_qtcp_tests.jl`](../../../test/general/protocolzoo_qtcp_tests.jl), [`protocolzoo_mbqc_tests.jl`](../../../test/general/protocolzoo_mbqc_tests.jl), [`protocolzoo_cutoff_cleanup_tests.jl`](../../../test/general/protocolzoo_cutoff_cleanup_tests.jl), [`myswapper_tutorial_tests.jl`](../../../test/examples/myswapper_tutorial_tests.jl)
- **Nonconformance:** No generated-pair test asserts reciprocal equal nonzero IDs, and
  no uncontended swap asserts the exact consumed-ID combination. Stale/update routes
  remain split, and QTCP/MBQC tests do not exercise adversarial valid interleavings or
  prove lock-and-revalidation coverage. Protocol surface tests do not verify that
  generated field docs distinguish supported configuration from unstable `_log` and
  `_backlog` runtime storage.

## UNITV-012 — Verify stable log groups and built-in optional activation

- **Covers:** CMP-013
- **Method:** test
- **Procedure:** Capture representative records from every documented log group, then
  load isolated environments with optional dependencies absent, partially present, and
  fully present for each declared repository-owned extension and invoke its renderers.
- **Environment / configuration:** Core and temporary extension projects plus
  configured plotting backends.
- **Pass criterion:** Each representative record uses its documented `LOG_GROUPS`
  value; no event name, field layout, message, or sequence is compared. Core loading
  succeeds in every dependency state, an optional implementation is selected only when
  its complete declared set is present, and every supported renderer completes without
  a content comparison.
- **Status:** implemented
- **Evidence:** [`Project.toml`](../../../Project.toml), [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl)
- **Nonconformance:** Logging tests sample groups rather than covering the full stable
  inventory; no clean absent/partial/full activation matrix or complete renderer-success
  fixture exists. Some cited renderer tests also assert exact tooltip or HTML content,
  so they are not isolated success-only contract probes.
