# Protocols Catalog

- **Context need:** Reference
- **Open when:** Choosing among shipped resumable protocols or assessing their current maturity.
- **Do not open when:** Adding a protocol, selecting an immediate circuit, or changing transport internals.
- **Related specification IDs:** SYS-005, SYS-008, SYS-009, SUB-013, CMP-012
- **Review when:** ProtocolZoo includes/exports, protocol families, or known maturity limits change.

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

Every documented and public family is long-term supported intent under SYS-008 and
SUB-013; implementation completeness still varies. QTCP contains unresolved drop
detection, correction, and timeout work. MBQC currently uses contiguous node-number
arithmetic in routing/mapping code, so it must not be assumed correct for arbitrary
graph labels. Entanglement pair identifiers can collide with the zero sentinel under
the current combination scheme. Switch tests cover several stale-match and
reciprocal-delete races, but do not prove every scheduler policy.

Public protocol constructors generally use documented DocStringExtensions field tables.
Those tables describe constructor parameters; concrete struct layout is not stable.
`AbstractProtocol`, process wiring, `permits_virtual_edge`, and logging-context
overloads are internal implementation seams rather than third-party extension APIs.
Current human docs teach custom `AbstractProtocol` and `protocol_log_context` methods,
which is a public-boundary mismatch tracked by SYS-009.

## Anchors

- **Source:** [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl), [`src/ProtocolZoo/switches.jl`](../../../src/ProtocolZoo/switches.jl), [`src/ProtocolZoo/qtcp.jl`](../../../src/ProtocolZoo/qtcp.jl), and [`src/ProtocolZoo/mbqc.jl`](../../../src/ProtocolZoo/mbqc.jl) — core and specialist families.
- **Docs:** [`docs/src/API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md) and [`docs/src/zoos_as_building_blocks.md`](../../../docs/src/zoos_as_building_blocks.md) — public catalog and reuse guidance.
- **Test:** [`test/general/protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl), [`test/general/protocolzoo_switch_tests.jl`](../../../test/general/protocolzoo_switch_tests.jl), [`test/general/protocolzoo_qtcp_tests.jl`](../../../test/general/protocolzoo_qtcp_tests.jl), and [`test/general/protocolzoo_mbqc_tests.jl`](../../../test/general/protocolzoo_mbqc_tests.jl) — family surfaces.

## Known gaps

- QTCP has incomplete drop, correction, and timeout behavior.
- MBQC assumes contiguous node labels in several paths.
- Combined entanglement identifiers can collide with the zero sentinel.
- Human guidance presents internal protocol hooks as third-party extension seams.
