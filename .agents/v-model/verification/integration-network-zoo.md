# Network, Zoo, and Extension Integration Verification

These actions exercise composed transport, catalog, protocol, inspection, and activation
boundaries.

## INTV-004 — Verify network construction and delayed transports

- **Covers:** SUB-007, SUB-008, SUB-009
- **Method:** test
- **Procedure:** Construct an asymmetric three-node network; run direct/forwarded
  messages, noisy correlated quantum transfer from an assigned source whose access time
  does not exceed arrival, occupied receipt, malformed counts, and incompatible domains.
- **Environment / configuration:** Root tests with unused registers, nonzero delays,
  discriminating background, and empty positive-fixture destination.
- **Pass criterion:** Resources share one clock; every edge has both directed channel
  pairs and directional values; every location has one incoming store; malformed counts
  and incompatible domains fail. Direct messages reach only their destination after
  delay; nonadjacent direct send fails, while forwarding follows declared edges and
  preserves payload. Quantum send unassigns the source immediately, leaves the
  destination unchanged before arrival, assigns it at arrival, preserves reciprocal
  backreferences/correlation, matches the background reference, and rejects an assigned
  destination.
- **Status:** implemented
- **Evidence:** [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl), [`messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), [`quantumchannel_tests.jl`](../../../test/general/quantumchannel_tests.jl)
- **Nonconformance:** Forwarding, malformed counts, and incompatible domains lack
  passing tests; count mismatch currently does not throw. Quantum tests omit exact
  send/pre-arrival/arrival transitions and in-transit backreferences. Occupied receipt
  dequeues before vacancy checking, so recovery is not established.

## INTV-006 — Verify StateZoo and CircuitZoo through registers

- **Covers:** SUB-011, SUB-012
- **Method:** test
- **Procedure:** Run built-in normalized/weighted states and swap, purification,
  encoding/decoding, and fusion; load external state/circuit fixtures and compare core
  source plus built-in baselines.
- **Environment / configuration:** Root tests plus clean external packages against the
  pinned revision.
- **Pass criterion:** Each state accepts ordered parameters, has correct arity, lowers
  in every designated representation, has unit or documented weighted trace, and
  exposes one same-order range per parameter. Each circuit reports its required arity,
  returns its documented shape, advances no time, removes destructive inputs, and
  preserves retained success outputs. External state/circuit fixtures use the same
  boundaries, return asserted results without core changes, and leave built-in
  baselines unchanged.
- **Status:** implemented
- **Evidence:** [`stateszoo_api_tests.jl`](../../../test/general/stateszoo_api_tests.jl), [`circuitzoo_api_tests.jl`](../../../test/general/circuitzoo_api_tests.jl), [`circuitzoo_ent_swap_tests.jl`](../../../test/general/circuitzoo_ent_swap_tests.jl), [`circuitzoo_fusion_tests.jl`](../../../test/general/circuitzoo_fusion_tests.jl), [`circuitzoo_superdense_tests.jl`](../../../test/general/circuitzoo_superdense_tests.jl), [`circuitzoo_purification_tests.jl`](../../../test/general/circuitzoo_purification_tests.jl)
- **Nonconformance:** No external fixtures or baselines exist. State checks are weak
  and a depolarized test is undiscovered; circuit timing, arity, and Stringent/Node
  effects are incomplete.

## INTV-007 — Verify asynchronous protocols and stale-state cleanup

- **Covers:** SUB-013
- **Method:** test
- **Procedure:** Run built-in and external protocol lifecycles with deterministic IDs
  and injected pre-lock, delayed, stale, switch, and cutoff cases; compare source and a
  built-in baseline.
- **Environment / configuration:** Root chain/grid tests plus a clean external protocol
  package against the pinned revision.
- **Pass criterion:** Generated pairs have reciprocal identity metadata; delayed
  updates affect only matching current/history state; an invalidated snapshot is not
  consumed; and successful resources are removed exactly once. The external protocol
  uses the same control boundaries, returns its asserted result without core changes,
  and leaves the built-in baseline unchanged.
- **Status:** implemented
- **Evidence:** [`protocolzoo_entangler_tests.jl`](../../../test/general/protocolzoo_entangler_tests.jl), [`protocolzoo_entanglement_consumer_stale_query_tests.jl`](../../../test/general/protocolzoo_entanglement_consumer_stale_query_tests.jl), [`protocolzoo_entanglement_counterpart_invariant_tests.jl`](../../../test/general/protocolzoo_entanglement_counterpart_invariant_tests.jl), [`protocolzoo_entanglement_tracker_lock_gap_tests.jl`](../../../test/general/protocolzoo_entanglement_tracker_lock_gap_tests.jl), [`protocolzoo_swapper_stale_query_tests.jl`](../../../test/general/protocolzoo_swapper_stale_query_tests.jl), [`protocolzoo_entanglement_id_tests.jl`](../../../test/general/protocolzoo_entanglement_id_tests.jl), [`protocolzoo_switch_stale_match_accounting_tests.jl`](../../../test/general/protocolzoo_switch_stale_match_accounting_tests.jl), [`protocolzoo_switch_stale_reciprocal_delete_tests.jl`](../../../test/general/protocolzoo_switch_stale_reciprocal_delete_tests.jl), [`protocolzoo_cutoff_cleanup_tests.jl`](../../../test/general/protocolzoo_cutoff_cleanup_tests.jl)
- **Nonconformance:** Separate tests do not jointly prove reciprocal creation, all
  delayed routes, revalidation, and exactly-once consumption. No external protocol or
  pre/post baseline exists.

## INTV-008 — Verify optional activation and structured logging

- **Covers:** SUB-014
- **Method:** test
- **Procedure:** Load absent, partial, complete, and external optional capabilities;
  invoke every entry point, capture diagnostics, and compare core source plus a built-in
  baseline.
- **Environment / configuration:** Isolated core/extension projects and plotting
  backends against the pinned revision.
- **Pass criterion:** Core loads without optional dependencies; partial sets do not
  activate incomplete extensions; complete sets dispatch. Diagnostics contain
  documented domain, event, simulation time, process/protocol identity, and ordered
  participants without mutable product objects. The external optional fixture uses the
  same activation boundary, returns its result without core changes, and leaves the core
  baseline unchanged.
- **Status:** implemented
- **Evidence:** [`Project.toml`](../../../Project.toml), [`logging_tests.jl`](../../../test/general/logging_tests.jl), [`interactiveutils_tests.jl`](../../../test/general/interactiveutils_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`cairo_tests.jl`](../../../test/plotting/cairo_tests.jl), [`gl_tests.jl`](../../../test/plotting/gl_tests.jl), [`show_png_tests.jl`](../../../test/plotting/show_png_tests.jl)
- **Nonconformance:** No clean activation matrix, external optional fixture, or pre/post
  baseline exists; logging covers only selected domains/events.

## INTV-009 — Verify inspection and metadata addressing

- **Covers:** SUB-015, SUB-016
- **Method:** test
- **Procedure:** Inspect and render unassigned, separate, and shared slots repeatedly;
  query a multi-edge network by graph/index and exercise vertex, undirected, directed,
  scalar-bulk, and function-bulk metadata.
- **Environment / configuration:** Root tests with before/after ownership, state, time,
  topology, and metadata snapshots.
- **Pass criterion:** Inspection returns no owner for an unassigned slot, distinct
  owners for separate slots, one owner listing exactly shared slots, and its native
  state; repeated inspection/rendering changes no owner identity, position, state, or
  access time. Indexed access returns intended registers/slots and graph queries the
  declared topology; vertex values remain local, tuple and graph-edge lookup return the
  same undirected value in either endpoint order, opposing directed values remain
  unequal, and scalar/function bulk assignment yields one retrievable value for every
  existing addressed vertex/edge.
- **Status:** implemented
- **Evidence:** [`observable_tests.jl`](../../../test/general/observable_tests.jl), [`show_html_tests.jl`](../../../test/general/show_html_tests.jl), [`show_gabs_tests.jl`](../../../test/general/show_gabs_tests.jl), [`registernet_interface_tests.jl`](../../../test/general/registernet_interface_tests.jl), [`registernet_metadata_access_tests.jl`](../../../test/general/registernet_metadata_access_tests.jl)
- **Nonconformance:** No test directly covers `stateof`/`quantumstate`/`slots` for all
  assignment shapes or proves rendering leaves every identity, position, value, and
  time unchanged. Network metadata coverage is strong but not one complete fixture.
