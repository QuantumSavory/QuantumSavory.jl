# Protocols Catalog

- **Context need:** Reference
- **Open when:** Choosing among shipped resumable protocols or assessing their current maturity.
- **Do not open when:** Adding a protocol, selecting an immediate circuit, or changing transport internals.
- **Related specification IDs:** SYS-008, SUB-013, CMP-012
- **Review when:** ProtocolZoo includes/exports, protocol families, or known maturity limits change.

## Protocol families

ProtocolZoo contains callable `AbstractProtocol` values run as SimJulia processes.
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

Maturity varies. QTCP contains unresolved drop detection, correction, and timeout work.
MBQC currently uses contiguous node-number arithmetic in routing/mapping code, so it
must not be assumed correct for arbitrary graph labels. Entanglement pair identifiers
can collide with the zero sentinel under the current combination scheme. Switch tests
cover several stale-match and reciprocal-delete races, but do not prove every scheduler
policy.

Treat catalog membership as reusable implementation, not a guarantee of production
completeness. Check the relevant test family and unresolved source TODOs before basing a
new protocol on QTCP or MBQC behavior.

## Anchors

- **Source:** [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl), [`src/ProtocolZoo/switches.jl`](../../../src/ProtocolZoo/switches.jl), [`src/ProtocolZoo/qtcp.jl`](../../../src/ProtocolZoo/qtcp.jl), and [`src/ProtocolZoo/mbqc.jl`](../../../src/ProtocolZoo/mbqc.jl) — core and specialist families.
- **Docs:** [`docs/src/API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public catalog and reuse guidance.
- **Test:** [`test/general/protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl), [`test/general/protocolzoo_switch_tests.jl`](../../../test/general/protocolzoo_switch_tests.jl), [`test/general/protocolzoo_qtcp_tests.jl`](../../../test/general/protocolzoo_qtcp_tests.jl), and [`test/general/protocolzoo_mbqc_tests.jl`](../../../test/general/protocolzoo_mbqc_tests.jl) — family surfaces.

## Unresolved questions

- Which QTCP features define its minimum complete contract?
- Must MBQC support arbitrary node labels?
- How should combined entanglement identifiers avoid the zero sentinel?
