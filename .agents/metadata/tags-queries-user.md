# Tags, Queries, and Message Buffers

Open this file when:

- you need protocols to publish or discover resources by metadata;
- you need to query register-slot tags or consume classical messages;
- you are writing protocol code that should wait for facts instead of hard-wiring peer handles.

Do not use this file for:

- tag representation internals;
- query specialization details;
- review of ordering or storage invariants.

Use `.agents/metadata/tags-queries-dev.md` for those.

## Mental Model

- Tags are structured classical facts.
- The same matching style is used in two places:
  - register slots, where tags describe quantum resources;
  - message buffers, where tags act as classical messages.
- Queries let independently written protocols coordinate by semantic facts rather than direct references.

## Common Patterns

Register metadata:

```julia
tag!(reg[1], :ready, 7)
tag!(reg[2], :ready, 9)

query(reg, :ready, 7)
queryall(reg, :ready, W)
querydelete!(reg, :ready, 9)
```

Waiting for matching metadata:

```julia
result = @yield query_wait(reg, :ready, W)
msg = @yield querydelete_wait!(messagebuffer(net, 2), :swap_request)
```

## Public APIs To Prefer

- Tagging register slots:
  - `tag!`
  - `untag!`
- Querying:
  - `query`
  - `queryall`
  - `querydelete!`
- Waiting helpers:
  - `query_wait`
  - `querydelete_wait!`
- Match helpers:
  - `W`
  - `Tag(...)`

## Usage Guidance

- Use typed tags when several protocols need to share a stable schema.
- Use plain symbolic tags for simple stage markers or one-off control flow.
- Use `locked=` and `assigned=` filters when resource availability matters, especially in networking protocols.
- Use `querydelete!` or `querydelete_wait!` when the tag or message is consumable state.
- Prefer waiting helpers over manual `while true` polling loops.

## Public Boundary

- Use `tag!` only on register slots like `reg[i]`.
- Use `put!` for message buffers and classical channels.
- `queryall` is for registers, not message buffers.

## Good Docs And Examples To Open Next

- `docs/src/metadata_plane.md`
- `docs/src/tag_query.md`
- `docs/src/classical_messaging.md`
- `docs/src/discreteeventsimulator.md`
- `docs/src/howto/repeatergrid/repeatergrid.md`
- `docs/src/howto/firstgenrepeater_v2/firstgenrepeater_v2.md`
- `../writeup/Tags.tex`

## Common Mistakes

- Hard-wiring protocols together when a shared tag schema would compose better.
- Using `tag!` on a message buffer instead of `put!`.
- Forgetting `locked=` or `assigned=` filters when multiple processes compete for slots.
- Assuming consumed messages should stay in the buffer after handling.
