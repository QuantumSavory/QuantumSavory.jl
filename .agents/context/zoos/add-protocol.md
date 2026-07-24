# Add a Protocol

- **Context need:** Task playbook
- **Open when:** Adding a reusable resumable protocol and its tags, logging, tests, and documentation.
- **Do not open when:** Merely choosing a shipped protocol or implementing an immediate local circuit.
- **Related specification IDs:** SYS-004, SYS-005, SYS-008, SYS-009, SUB-013, CMP-012, CMP-013
- **Review when:** `AbstractProtocol`, shorthand constructors, tag/query semantics, or logging conventions change.

## Add the protocol

1. Define a configuration-bearing `AbstractProtocol` subtype and resumable callable
   body. Let the standard shorthand derive its simulation from `RegisterNet`; verify
   `get_time_tracker` and participating-node context rather than accepting an unrelated
   simulation.
2. Define typed tags for durable protocol facts. Preserve fixed payload shapes and
   decide identifier/sentinel behavior explicitly. A configurable head typed as
   `Type{<:AbstractTag}` must be a concrete subtype. Add `Tag` conversion and compact
   display only when needed by the shared metadata surface.
3. Design the yield boundaries before implementation. Query snapshots become stale
   across every wait. Acquire resources, revalidate reciprocal metadata and occupancy,
   mutate, and release on all exits. Use `querydelete_wait!` only when consumption is
   the intended wake contract.
4. Define cleanup for partial completion. Tags, classical sends, quantum moves,
   measurements, and traceout are not one transaction. Cover timeout, cancellation,
   occupied destinations, missing counterparts, and competing consumers.
5. Override `permits_virtual_edge(::Type{MyProtocol}) = true` only if the protocol is
   valid without a physical graph edge; the default is false and instance queries
   delegate to the type.
6. Emit records under `LOG_GROUPS.protocol` with `protocol_log_context`. Its base fields
   are primitive simulation values, a protocol-name `Symbol`, and an immutable ordered
   node tuple; do not store live objects. Stable groups do not freeze every event field.
7. Include and export the intended surface from ProtocolZoo. Add the protocol to the
   human API and a runnable example when it teaches composition; avoid copying the full
   field catalog into agent context.
8. Test happy-path completion and forced races. Add stale-query, reciprocal-tag,
   cleanup, shorthand-simulation, logging-context, and virtual-edge cases as applicable.
   Run the focused tests followed by the general shard.

Use the detailed [protocol race playbook](../network/protocol-development.md) during
review. Do not copy unresolved QTCP drop/correction/timeout behavior or MBQC contiguous
node arithmetic as a design contract.

## Anchors

- **Source:** [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl), [`src/ProtocolZoo/qtcp.jl`](../../../src/ProtocolZoo/qtcp.jl), and [`src/ProtocolZoo/mbqc.jl`](../../../src/ProtocolZoo/mbqc.jl) — extension seam and mature/immature examples.
- **Docs:** [`docs/src/API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md), [`docs/src/discreteeventsimulator.md`](../../../docs/src/discreteeventsimulator.md), and [`docs/src/tutorial/myswapperprot.md`](../../../docs/src/tutorial/myswapperprot.md) — public API and authoring walkthrough.
- **Test:** [`test/general/protocolzoo_shorthand_constructors_tests.jl`](../../../test/general/protocolzoo_shorthand_constructors_tests.jl), [`test/general/protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl), and [`test/general/protocolzoo_throws_tests.jl`](../../../test/general/protocolzoo_throws_tests.jl) — construction, surface, and failure examples.

## Unresolved questions

- Should ProtocolZoo provide shared transactional cleanup helpers?
- Which protocol event fields should become stable consumer contracts?
