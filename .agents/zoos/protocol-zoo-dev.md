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
- `src/ProtocolZoo/entanglement_ids.jl` defines pair ID generation and the commutative/associative accumulator used by the tracker.
- `src/ProtocolZoo/swapping.jl` contains slot-selection and swapper logic.
- `src/ProtocolZoo/cutoff.jl` handles stale-entanglement cleanup.
- `src/ProtocolZoo/qtcp.jl` is a higher-level protocol stack built on the same tag/message model.
- `src/ProtocolZoo/switches.jl` is a separate subsystem with its own request and matching machinery.

## Extension Pattern

- Subtype `AbstractProtocol`.
- Store `sim` and `net` in the protocol object.
- Implement `@resumable function (prot::MyProt)()`.
- Overload `protocol_log_context(prot::MyProt)` with only primitive simulation
  fields, `protocol::Symbol`, and an immutable ordered node tuple. Do not retain
  the simulation, network, protocol, register, message, or query objects in the
  returned context.
- Emit protocol records with an explicit `_group=LOG_GROUPS.protocol`, a stable
  `event::Symbol`, and `protocol_log_context(prot)...`. Keep runtime-selected
  peers in `src_node`, `dst_node`, or `remote_nodes`, not in the base context.
- Reuse existing tag/message schemas when possible:
  - `EntanglementCounterpart(remote_node, remote_slot, pair_id)`
  - `EntanglementHistory(remote_node, remote_slot, swap_remote_node, swap_remote_slot, swapped_local, local_chunk_id, swapped_chunk_id)`
  - `EntanglementUpdateX(target_pair_id, other_pair_id, past_local_node, past_local_slot, past_remote_slot, new_remote_node, new_remote_slot, correction)`
  - `EntanglementUpdateZ(target_pair_id, other_pair_id, past_local_node, past_local_slot, past_remote_slot, new_remote_node, new_remote_slot, correction)`
  - `EntanglementDelete(target_pair_id, send_node, send_slot, rec_node, rec_slot)`
- Named tag-head structs used by the zoo are concrete `AbstractTag` subtypes.
  Preserve the exact configuration-field contracts: `EntanglerProt.tag`
  permits such a type or `nothing`, while `EntanglementConsumer.tag` requires
  such a type.
- If the protocol intentionally works across non-physical edges, define `permits_virtual_edge(::Type{<:MyProt}) = true`; instance queries delegate to this type-level trait.

## Review Checks

- Check lock acquisition and release on every path.
- Check every `query`/`queryall` result that is used after `@yield`, `lock`,
  `timeout`, `onchange`, or a spawned process runs. Register query results are
  snapshots; ids and slot/tag relations can be stale by the time the protocol
  resumes.
- If a protocol consumes a tag, prefer `querydelete_wait!` or re-query under
  the acquired locks before `untag!`. Avoid deleting one side of a pair before
  confirming the other side is still current.
- Verify whether the protocol only behaves correctly when paired with `EntanglementTracker`.
- Treat field-position access like `tag[2]` and `tag[3]` as brittle review hotspots.
- For tracker-related changes, cross-check:
  - nonzero `classical_delay`
  - `CutoffProt.retention_time`
  - `CutoffProt.max_delete_per_slot`
  - `SwapperProt.agelimit`
  - `SwapperProt.max_history_per_slot`
- Keep shorthand constructors like `Prot(net, ...)` aligned with tests.
- When migrating custom entangler/consumer tags, define a concrete
  `AbstractTag` subtype; do not constrain generic `Tag(::DataType, ...)`
  construction as a side effect.
- For QTCP changes, review the `Tag(...)` serialization and matching query shape together.
- Review log records by group, event, and metadata rather than matching rendered
  message strings. `_group` is the only field available to `shouldlog` before
  message and context construction.

## Source Files To Read

- `src/ProtocolZoo/ProtocolZoo.jl`
- `src/ProtocolZoo/entanglement_ids.jl`
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
- `docs/src/howto/firstgenrepeater/firstgenrepeater.md`
- `docs/src/howto/repeatergrid/repeatergrid.md`
- `docs/src/howto/simpleswitch/simpleswitch.md`
