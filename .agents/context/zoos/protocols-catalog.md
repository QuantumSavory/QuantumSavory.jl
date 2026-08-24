# Protocols Catalog

- **Context need:** Reference
- **Open when:** Choosing among shipped resumable protocols or assessing their current implementation status.
- **Do not open when:** Adding a protocol, selecting an immediate circuit, or changing transport internals.
- **Review when:** ProtocolZoo includes/exports, protocol families, or known implementation gaps change.

## Protocol families

ProtocolZoo contains callable `AbstractProtocol` values run as ConcurrentSim processes.
Constructor shorthands derive the simulation from the supplied `RegisterNet`; callers
should not maintain a separate clock. Use the human API for fields and signatures.

The core family covers link entanglement generation (`EntanglerProt`), swapping
(`SwapperProt`), counterpart propagation (`EntanglementTracker`), consumption
(`EntanglementConsumer`), and age-based cleanup (`CutoffProt`). These protocols
coordinate register resources and fixed metadata tags across yields.

`switches.jl` adds discrete switch scheduling and request tags. `qtcp.jl` adds flows,
datagrams, link requests/replies, and end/network/link controllers. `mbqc.jl` adds graph
state construction, graph-to-resource mapping, purification measurements, and tracking.
All three are part of ProtocolZoo, not separate external zoos.

QTCP `LinkController` has two supported link-resource modes. The default mode runs its
one-shot entangler for each request. External mode takes reciprocal pairs identified by
a configured concrete tag type, newest first by default or oldest first with
`filo=false`. It keeps the per-link request resource while waiting, locks and revalidates
both slots, removes only the two inventory tags, and retains the quantum state for QTCP.
Stale, asymmetric, mismatched, or duplicated metadata is not partly consumed.

Every documented and public family is intended for long-term support; implementation
completeness still varies. QTCP contains unresolved drop detection, correction, and
timeout work. MBQC currently uses contiguous node-number arithmetic in routing/mapping
code, so it must not be assumed correct for arbitrary graph labels. Entanglement pair
identifiers can collide with the zero sentinel under the current combination scheme.
Switch tests cover several stale-match and reciprocal-delete races, but do not prove
every scheduler policy.

The supported authoring surface includes the documented `AbstractProtocol` callable
pattern, virtual-edge capability, logging-context overload, and the
`protocol_catalog_metadata` opt-in trait, so external libraries can define reusable
protocols in the same style as ProtocolZoo. The InteractiveUtils catalog discovers
loaded public types recursively and validates attachment roles against documented
constructor fields. Public protocol constructors generally use DocStringExtensions
field tables. Configuration fields are supported constructor inputs; runtime
bookkeeping fields such as `_log` and `_backlog` are explicitly internal and their
storage types may change.

## Anchors

- **Source:** [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl), [`src/ProtocolZoo/switches.jl`](../../../src/ProtocolZoo/switches.jl), [`src/ProtocolZoo/qtcp.jl`](../../../src/ProtocolZoo/qtcp.jl), and [`src/ProtocolZoo/mbqc.jl`](../../../src/ProtocolZoo/mbqc.jl) — core and specialist families.
- **Docs:** [`docs/src/API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public catalog and reuse guidance.
- **Test:** [`test/general/protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl), [`test/general/protocolzoo_switch_tests.jl`](../../../test/general/protocolzoo_switch_tests.jl), [`test/general/protocolzoo_qtcp_tests.jl`](../../../test/general/protocolzoo_qtcp_tests.jl), [`test/general/protocolzoo_qtcp_external_inventory_tests.jl`](../../../test/general/protocolzoo_qtcp_external_inventory_tests.jl), and [`test/general/protocolzoo_mbqc_tests.jl`](../../../test/general/protocolzoo_mbqc_tests.jl) — family surfaces and QTCP inventory races.

## Known gaps

- QTCP has incomplete drop, correction, and timeout behavior.
- MBQC assumes contiguous node labels in several paths.
- Combined entanglement identifiers can collide with the zero sentinel.
- The documented qualified `promponas_bruteforce_choice` switch selector and Zoo module
  bindings lack `public` declarations.
- Generated constructor-reference coverage is not mechanically audited. Runtime
  `_log`/`_backlog` storage remains accepted by generated `@kwdef` constructor paths and
  is read by examples even though its concrete type is not a supported interface.
