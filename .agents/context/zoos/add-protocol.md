# Add a Protocol

- **Context need:** Task playbook
- **Open when:** Adding a reusable resumable protocol and its tags, logging, tests, and documentation.
- **Do not open when:** Merely choosing a shipped protocol or implementing an immediate local circuit.
- **Review when:** `AbstractProtocol`, shorthand constructors, tag/query semantics, or logging conventions change.

## Add a reusable protocol

1. Define a configuration-bearing `AbstractProtocol` subtype and resumable callable
   body. This is the supported reusable-protocol extension pattern. Let the standard
   shorthand derive its simulation from `RegisterNet`; verify the selected time tracker
   and participating-node context rather than accepting an unrelated simulation.
2. Define typed tags for durable protocol facts. Preserve fixed payload shapes and
   decide identifier/sentinel behavior explicitly. A configurable head typed as
   `Type{<:AbstractTag}` must be a concrete subtype. Add `Tag` conversion and compact
   display only when needed by the shared metadata surface.
3. Design the yield boundaries before implementation. Query snapshots become stale
   across every wait. Acquire resources, revalidate reciprocal metadata and occupancy,
   mutate, and release on every modeled completion, timeout, or cancellation path. Use
   `querydelete_wait!` only when consumption is the intended wake contract.
4. Define cleanup for modeled partial completion. Tags, classical sends, quantum moves,
   measurements, and traceout are separate mutations. Cover ordinary timeout,
   cancellation, missing-counterpart, and competing-consumer branches. An occupied
   quantum receipt throws after losing the transmitted state; the intended warning is
   not implemented, and no rollback should be added solely to recover that simulation.
5. Override `permits_virtual_edge(::Type{MyProtocol}) = true` only if the protocol is
   valid without a physical graph edge. This documented capability hook is part of the
   protocol extension interface.
6. Emit records under `LOG_GROUPS.protocol` with the public `protocol_log_context`
   extension point. Its base fields currently use primitive simulation values; do not
   store live objects. The helper is supported, while only the log group is a stable
   logging schema.
7. Include the type and export or declare it public. Document every argument accepted
   by its public constructors without promising concrete struct layout. Add API
   reference and a user-oriented example; avoid copying the field catalog into agent
   context.
8. Test happy-path completion and forced races. Add stale-query, reciprocal-tag,
   cleanup, shorthand-simulation, logging-context, and virtual-edge cases as applicable.
   Run the focused tests followed by the general shard.

Use the detailed [protocol race playbook](../network/protocol-development.md) during
review. Do not copy unresolved QTCP drop/correction/timeout behavior or MBQC contiguous
node arithmetic as a design contract.

## Anchors

- **Source:** [`src/ProtocolZoo/ProtocolZoo.jl`](../../../src/ProtocolZoo/ProtocolZoo.jl), [`src/ProtocolZoo/qtcp.jl`](../../../src/ProtocolZoo/qtcp.jl), and [`src/ProtocolZoo/mbqc.jl`](../../../src/ProtocolZoo/mbqc.jl) — extension pattern and contrasting completeness.
- **Docs:** [`docs/src/API_ProtocolZoo.md`](../../../docs/src/API_ProtocolZoo.md), [`docs/src/discreteeventsimulator.md`](../../../docs/src/discreteeventsimulator.md), and [`docs/src/tutorial/myswapperprot.md`](../../../docs/src/tutorial/myswapperprot.md) — public API and authoring walkthrough.
- **Test:** [`test/general/protocolzoo_shorthand_constructors_tests.jl`](../../../test/general/protocolzoo_shorthand_constructors_tests.jl), [`test/general/protocolzoo_surface_contracts_tests.jl`](../../../test/general/protocolzoo_surface_contracts_tests.jl), and [`test/general/protocolzoo_throws_tests.jl`](../../../test/general/protocolzoo_throws_tests.jl) — construction, surface, and failure examples.

## Supported boundary

The documented `AbstractProtocol` callable pattern, `permits_virtual_edge` capability,
and `protocol_log_context` overload are supported extension points. Public concrete
protocols and their documented constructors are also supported. Underscore-prefixed
runtime storage such as `_log` and `_backlog` is internal; its concrete type may change
between compatible versions even when generated field documentation displays it.
