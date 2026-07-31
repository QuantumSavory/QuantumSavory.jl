# Network, Zoo, and Extension Integration Verification

These actions exercise composed transport, catalog, protocol, inspection, and activation
boundaries.

## INTV-004 — Verify network construction and delayed transports

- **Covers:** SUB-007, SUB-008, SUB-009
- **Method:** test
- **Procedure:** Construct an asymmetric branching network with distinguishable
  multi-hop alternatives; run direct/forwarded messages, noisy correlated quantum
  transfer from an assigned source whose access time does not exceed arrival, occupied
  receipt, malformed counts, and incompatible domains.
- **Environment / configuration:** Root tests with unused registers, nonzero delays,
  discriminating background, and empty positive-fixture destination.
- **Pass criterion:** Resources share one clock; every edge has both directed channel
  pairs and directional values; every location has one incoming store. Malformed counts
  and incompatible simulation domains are rejected during construction. Direct
  messages reach only their destination after delay; nonadjacent direct send fails,
  while forwarding selects the shortest declared path and preserves the payload.
  Under valid source timing, quantum send unassigns the source immediately, leaves an
  empty destination unchanged before arrival, assigns it at arrival, preserves
  reciprocal backreferences/correlation, and matches the background reference.
  Receipt into an occupied destination reports failure, discards the transmitted state,
  and warns; no recovery or other post-exception consistency is asserted.
- **Status:** implemented
- **Evidence:** [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** No forwarding test distinguishes alternative paths; malformed
  counts and incompatible domains lack passing tests, and count mismatch currently does
  not throw. Quantum tests omit exact
  send/pre-arrival/arrival transitions and in-transit backreferences. Occupied receipt
  discards the dequeued state as intended but does not warn.

## INTV-006 — Verify StatesZoo and CircuitZoo through registers

- **Covers:** SUB-011, SUB-012
- **Method:** test
- **Procedure:** Derive the public state/circuit inventories from generated docs and
  `export`/`public` declarations; run every normalized/weighted state and every basic or
  advanced public swap, purification, encoding/decoding, and fusion circuit, then run
  their user-oriented examples.
- **Environment / configuration:** Root and examples projects with every entry's
  documented compatible representation subset.
- **Pass criterion:** Each public state documents its constructor parameters, accepts
  them in order, reports expected-value introspection in the same order, has declared
  arity, lowers in every designated representation, and has unit or documented
  weighted trace. Each public circuit documents its callable contract, exposes a
  consistent public feature API including required arity, returns its documented shape,
  advances no time, removes destructive inputs, and preserves retained success outputs.
  Internal helpers appear in neither public inventory; every public family has API
  reference coverage and a user-oriented example.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), [`circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl), [`circuitzoo_superdense_tests.jl`](../../../test/general/circuitzoo_superdense_tests.jl), [`circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl)
- **Nonconformance:** Public inventories, documentation fields, and examples are not
  checked mechanically. State checks are weak, Barrett-Kok introspection omits `m`,
  weighted constructor prose is incomplete, and a depolarized test is undiscovered;
  circuit feature introspection, timing, and Stringent/Expedient/Node arity, return, and
  cleanup behavior are incomplete.

## INTV-007 — Verify asynchronous protocols and stale-state cleanup

- **Covers:** SUB-013
- **Method:** test
- **Procedure:** Derive the public protocol inventory from generated docs and
  `export`/`public` declarations; run core entangler/tracker/swapper/consumer/cutoff,
  Switch, QTCP, and MBQC lifecycles with deterministic IDs and injected pre-lock,
  delayed, stale, switch, and cutoff cases, then run each family's user example.
- **Environment / configuration:** Root and examples projects with documented valid
  scheduling and lock usage.
- **Pass criterion:** Generated pairs have reciprocal identity metadata; delayed
  updates affect only matching current/history state; an invalidated snapshot is not
  consumed; and successful resources are removed exactly once. Every public protocol
  documents every constructor parameter, has API-reference coverage and a user-oriented
  example, and remains race-free under documented valid usage. Internal lifecycle hooks
  and helper types are absent from the public inventory.
- **Status:** implemented
- **Evidence:** [`API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md), [`protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl), [`protocolzoo_entangler_tests.jl`](../../../test/general/protocolzoo_entangler_tests.jl), [`protocolzoo_entanglement_consumer_stale_query_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_stale_query_tests.jl), [`protocolzoo_entanglement_counterpart_invariant_tests.jl`](../../../test/general/protocolzoo_entanglement_counterpart_invariant_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl), [`protocolzoo_switch_stale_match_accounting_tests.jl`](../../../test/general/protocolzoo_switch_stale_match_accounting_tests.jl), [`protocolzoo_switch_stale_reciprocal_delete_tests.jl`](../../../test/general/protocolzoo_switch_stale_reciprocal_delete_tests.jl), [`protocolzoo_qtcp_tests.jl`](../../../test/general/protocolzoo_qtcp_tests.jl), [`protocolzoo_mbqc_tests.jl`](../../../test/general/protocolzoo_mbqc_tests.jl), [`protocolzoo_cutoff_cleanup_tests.jl`](../../../test/general/protocolzoo_cutoff_cleanup_tests.jl), [`qtcp_tutorial_1_tests.jl`](../../../test/examples/qtcp_tutorial_1_tests.jl), [`purificationmbqc_tests.jl`](../../../test/examples/purificationmbqc_tests.jl)
- **Nonconformance:** Separate tests do not jointly prove reciprocal creation, all
  delayed routes, revalidation, and exactly-once consumption. The public inventory and
  constructor docs are not enforced; QTCP/MBQC lack core-level evidence. Generated
  keyword constructors still accept internal `_log`/`_backlog` storage.

## INTV-008 — Verify built-in optional activation, log groups, and rendering

- **Covers:** SUB-014
- **Method:** test
- **Procedure:** Load each declared weak-dependency set absent, partially present, and
  complete; invoke every repository-owned optional entry point and renderer, and
  capture representative records from every documented log group.
- **Environment / configuration:** Isolated core, interactive, plotting, and map
  projects at the revision under review.
- **Pass criterion:** Core loads without optional dependencies; partial sets do not
  activate incomplete extensions; complete sets dispatch and their integrations operate
  correctly when dependencies are available. Representative records use the documented
  stable log groups, and every supported text, HTML, PNG, plotting, interactive, and map
  renderer completes. No other log field or rendered content is compared.
- **Status:** implemented
- **Evidence:** [`Project.toml`](../../../Project.toml), [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl)
- **Nonconformance:** No clean activation matrix exists; logging covers only selected
  groups, renderer coverage is incomplete, and map tests depend on an external tile
  service. Activation and logging hooks are internal, not public extension seams.
  Some cited tests mix exact-content regressions with success probes.

## INTV-009 — Verify inspection and metadata addressing

- **Covers:** SUB-015, SUB-016
- **Method:** test
- **Procedure:** Inspect unassigned, separate, and shared slots repeatedly; query a
  multi-edge network by graph/index and exercise vertex, undirected, directed,
  scalar-bulk, and function-bulk metadata; invoke each renderer as a success probe.
- **Environment / configuration:** Root tests with before/after ownership, state, time,
  topology, and metadata snapshots.
- **Pass criterion:** Inspection returns no owner for an unassigned slot, distinct
  owners for separate slots, one owner listing exactly shared slots, and its native
  state; repeated inspection changes no owner identity, position, state, or access time.
  Indexed access returns intended registers/slots and graph queries the
  declared topology; vertex values remain local, tuple and graph-edge lookup return the
  same undirected value in either endpoint order, opposing directed values remain
  unequal, and scalar/function bulk assignment yields one retrievable value for every
  existing addressed vertex/edge. Renderers complete; their content is unrestricted.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`show_gabs_tests.jl`](../../../test/general/show_gabs_tests.jl), [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl)
- **Nonconformance:** No test directly covers `stateof`/`quantumstate`/`slots` for all
  assignment shapes, and these documented unexported functions lack `public`
  declarations. Both directed bulk setters currently dispatch into the undirected
  store; coverage is otherwise strong but not one complete fixture. Cited display tests
  mix exact-content regressions with success probes.
