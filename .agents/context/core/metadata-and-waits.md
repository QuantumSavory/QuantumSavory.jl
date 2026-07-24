# Metadata and Waits

- **Context need:** Reference
- **Open when:** Checking tag payloads, indexed queries, consumption order, message buffers, or wake-up behavior.
- **Do not open when:** Editing quantum-state operations, network routing, or backend evolution.
- **Related specification IDs:** SYS-004, SYS-005, SUB-005, SUB-006, CMP-005, CMP-006
- **Review when:** Tag definitions, query indexing/order, `query_wait`, `MessageBuffer`, or `ChangeNotifier` changes.

## Metadata contract

Tags are typed metadata attached to register slots or stored in message buffers.
Concrete standard tags use fixed payload shapes: identifiers and slots are `Int`,
tag kinds are `Symbol` or a tag `DataType`, and selected protocol fields use declared
floating-point or type/symbol fields. Preserve these shapes when matching, forwarding,
or adding standard protocol metadata; do not describe them as arbitrary tuples.

Queries use indexes for tag identifier, slot, and head tag type where possible, then
apply predicates to candidates. Register queries default to FILO through `filo=true`;
`MessageBuffer` iterates insertion-order identifiers, so its selection is FIFO and it
does not provide the register `filo` or `queryall` options. A deleting query removes
the selected tag; a plain query returns it without reservation.

`query_wait` always performs the query first, then waits for a change only if no match
exists. It is always non-consuming and does not lock or reserve a matching tag;
`querydelete_wait!` is the consuming wait variant. The claim in
`docs/src/tag_query.md` that `query_wait` locks or reserves is stale and must not guide
implementations. Callers that require exclusivity must revalidate and consume under
their own protocol discipline.

The notification primitive is `ChangeNotifier`, not `AsymmetricSemaphore`. Register
waiters observe a register-wide future change edge. Message buffers also broadcast
changes, but their queued, unattended notification tokens make the exact wake behavior
different from a simple edge-triggered condition. Tests should distinguish “eventually
wakes and re-queries” from stronger one-notification/one-waiter assumptions.

Snapshot results can become stale between query and use because SimJulia processes
interleave at yields. Protocols should validate reciprocal tags, slot occupancy, and
pair identifiers immediately before destructive actions.

## Anchors

- **Source:** [`src/tags.jl`](../../../src/tags.jl), [`src/queries.jl`](../../../src/queries.jl), [`src/querywait.jl`](../../../src/querywait.jl), and [`src/messagebuffer.jl`](../../../src/messagebuffer.jl) — payload, indexing, query, and buffer behavior.
- **Docs:** [`docs/src/metadata_plane.md`](../../../docs/src/metadata_plane.md) and [`docs/src/tag_query.md`](../../../docs/src/tag_query.md) — human metadata model, including the identified stale locking claim.
- **Test:** [`test/general/tags_and_queries_tests.jl`](../../../test/general/tags_and_queries_tests.jl), [`test/general/querywait_tests.jl`](../../../test/general/querywait_tests.jl), and [`test/general/messagebuffer_tests.jl`](../../../test/general/messagebuffer_tests.jl) — ordering, waits, and buffer behavior.

## Unresolved questions

- Should the message-buffer notification queue be replaced or documented as part of the contract?
- Which protocol operations require a library-level atomic query-and-consume primitive?
