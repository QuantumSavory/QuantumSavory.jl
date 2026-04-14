# ProtocolZoo for Developers

Open this file when:

- adding or reviewing a protocol in `ProtocolZoo`;
- changing shared tag/message schemas;
- debugging tracker, swapper, cutoff, switch, or QTCP behavior;
- reviewing protocol concurrency assumptions.

Do not use this file for quick public API selection.
Use `.agents/zoos/protocol-zoo-user.md` for that.

## Internal Design

- `AbstractProtocol` is a callable-struct convention plus a `Process(prot::AbstractProtocol, ...)` bridge.
- `src/ProtocolZoo/ProtocolZoo.jl` defines the common entanglement tag schema and core protocols.
- `src/ProtocolZoo/swapping.jl` contains slot-selection and swapper logic.
- `src/ProtocolZoo/cutoff.jl` handles stale-entanglement cleanup.
- `src/ProtocolZoo/qtcp.jl` is a higher-level protocol stack built on the same tag/message model.
- `src/ProtocolZoo/switches.jl` is a separate subsystem with its own request and matching machinery.

## Extension Pattern

- Subtype `AbstractProtocol`.
- Store `sim` and `net` in the protocol object.
- Implement `@resumable function (prot::MyProt)()`.
- Reuse existing tag/message schemas when possible:
  - `EntanglementCounterpart`
  - `EntanglementHistory`
  - `EntanglementUpdateX`
  - `EntanglementUpdateZ`
  - `EntanglementDelete`
- If the protocol intentionally works across non-physical edges, define `permits_virtual_edge(::MyProt) = true`.

## Review Checks

- Check lock acquisition and release on every path.
- Verify whether the protocol only behaves correctly when paired with `EntanglementTracker`.
- Treat field-position access like `tag[2]` and `tag[3]` as brittle review hotspots.
- For tracker-related changes, cross-check:
  - nonzero `classical_delay`
  - `CutoffProt.retention_time`
  - `SwapperProt.agelimit`
- Keep shorthand constructors like `Prot(net, ...)` aligned with tests.
- For QTCP changes, review the `Tag(...)` serialization and matching query shape together.

## Source Files To Read

- `src/ProtocolZoo/ProtocolZoo.jl`
- `src/ProtocolZoo/swapping.jl`
- `src/ProtocolZoo/cutoff.jl`
- `src/ProtocolZoo/qtcp.jl`
- `src/ProtocolZoo/switches.jl`
- `src/ProtocolZoo/show.jl`

## Tests To Anchor Behavior

- `test/general/protocolzoo_entangler_tests.jl`
- `test/general/protocolzoo_entanglement_tracker_tests.jl`
- `test/general/protocolzoo_cutoffprot_tests.jl`
- `test/general/protocolzoo_entanglement_consumer_tests.jl`
- `test/general/protocolzoo_swapper_chooseslots_tests.jl`
- `test/general/protocolzoo_switch_tests.jl`
- `test/general/protocolzoo_throws_tests.jl`
- `test/general/protocolzoo_qtcp_tests.jl`
- `test/general/protocolzoo_shorthand_constructors_tests.jl`
- `test/general/protocolzoo_virtual_edge_tests.jl`

## Public Docs And Paper To Cross-Check

- `docs/src/API_ProtocolZoo.md`
- `docs/src/zoos_as_building_blocks.md`
- `docs/src/discreteeventsimulator.md`
- `docs/src/howto/firstgenrepeater_v2/firstgenrepeater_v2.md`
- `docs/src/howto/repeatergrid/repeatergrid.md`
- `docs/src/howto/simpleswitch/simpleswitch.md`