# Metadata and Waits

- **Context need:** Reference
- **Open when:** Checking tag payloads, indexed queries, consumption order, message buffers, or wake-up behavior.
- **Do not open when:** Editing quantum-state operations, network routing, or backend evolution.
- **Review when:** Tag definitions, query indexing/order, `query_wait`, `MessageBuffer`, or `ChangeNotifier` changes.

## Metadata contract

Tags are typed metadata attached to register slots or stored in message buffers.
Concrete standard tags use fixed payload shapes: identifiers and slots are `Int`, tag
kinds are `Symbol` or a tag `DataType`, and selected protocol fields use declared
floating-point or type/symbol fields. Public tag field order and types are the
compatibility boundary; do not describe them as arbitrary tuples.
Protocol fields typed as `Type{<:AbstractTag}` require a concrete subtype such as
`struct MyTag <: AbstractTag end`.

A full `Tag` can be matched exactly. Per-field query arguments accept exact
`Symbol`/`Int`/`DataType` values, `W`/`❓`, or a predicate (use a predicate for a
floating-point field). Register queries can additionally filter on the slot's `locked`
and `assigned` state. They default to FILO through `filo=true`; `MessageBuffer`
selection is FIFO and does not provide `locked`, `assigned`, `filo`, or `queryall`. A
deleting query removes the selected tag; a plain query returns it without reservation.

Duplicate tag values are allowed: each insertion receives a new identifier and no
uniqueness check is performed. Attach slot metadata with `tag!(regref, ...)`; insert a
buffer message with `put!(buffer, Tag(...))`. `tag!` on a buffer or whole register
raises an `ArgumentError`.

`query_wait` always performs the query first, then waits for a change only if no match
exists. It is always non-consuming and does not lock or reserve a matching tag;
`querydelete_wait!` is the consuming wait variant. The claim in
`docs/src/tag_query.md` states the same non-reservation rule. Callers that require
exclusivity must revalidate and consume under their own protocol discipline.

The notification primitive is `ChangeNotifier`, not `AsymmetricSemaphore`. Register
waiters observe a register-wide future change edge. Message buffers also broadcast
changes, but their queued, unattended notification tokens make the exact wake behavior
different from a simple edge-triggered condition. Tests should distinguish “eventually
wakes and re-queries” from stronger one-notification/one-waiter assumptions.
Both `onchange(::Register)` and `onchange(::MessageBuffer)` take effect before
returning: they attach to the current notifier generation, or the buffer consumes one
queued token. A later change is not lost while the caller starts waiting;
`test/general/messagebuffer_tests.jl`
pins this with a blocked bystander and a local `put!` immediately after `onchange`
returns, without relying on scheduler order.

`onchange` returns a private `ChangeWait` event. ConcurrentSim releases a completed
condition's input subscriptions before its consumer callbacks run. A change wait that
loses its last subscriber is abandoned and removes its exact notifier callback and
generation count. Another subscriber keeps a shared wait alive. Nested conditions
propagate cleanup, while `query_wait`, `querydelete_wait!`, ordinary processes, and
resource requests remain ordinary processes or events without general cancellation.
An abandoned wait cannot be reused, including after scheduled events drain; create
a fresh `onchange` wait. A normally completed wait remains yieldable.

Cleanup takes effect when the race is processed, before its caller resumes. An
arrival before that boundary can already have notified the wait. Subsequent unattended
buffer arrivals save a notification for later callers. Queued notifications consumed
when `onchange` is called are never refunded, including when that wait loses a race;
message deletion also does not remove queued notifications.

Snapshot results can become stale between query and use because ConcurrentSim processes
interleave at yields. Protocols should validate reciprocal tags, slot occupancy, and
pair identifiers immediately before destructive actions.

The generated standard-tag page also documents some qualified, unexported tag heads,
including `EntanglementDelete` and `QTCP.QDatagramSuccess`. They have no Julia `public`
declaration in this checkout, so their documented schema and source marking are not yet
aligned with the repository's public-API convention.

## Anchors

- **Source:** [`src/tags.jl`](../../../src/tags.jl), [`src/queries.jl`](../../../src/queries.jl), [`src/querywait.jl`](../../../src/querywait.jl), and [`src/messagebuffer.jl`](../../../src/messagebuffer.jl) — payload, indexing, query, and buffer behavior.
- **Docs:** [`docs/src/metadata_plane.md`](../../../docs/src/metadata_plane.md) and [`docs/src/tag_query.md`](../../../docs/src/tag_query.md) — metadata and query model.
- **Test:** [`test/general/tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`test/general/querywait_tests.jl`](../../../test/general/querywait_tests.jl), [`test/general/messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl), and [`test/general/onchange_races_tests.jl`](../../../test/general/onchange_races_tests.jl) — ordering, waits, buffer behavior, and abandoned subscriptions.
