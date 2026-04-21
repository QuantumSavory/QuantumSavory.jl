# [Tagging and Querying](@id tagging-and-querying)

This page is the API-focused reference for the metadata plane. For the
conceptual overview, start with [Metadata and Protocol Composition](@ref
metadata-plane).

## What Tags And Queries Are For

Tags are structured classical facts attached to quantum slots. Queries search
for those facts by exact value, wildcard, or predicate. This is how
independently written protocols discover resources without holding direct
references to each other.

In practice, this means a protocol can ask for:

- "a slot entangled with node 7",
- "any slot carrying this protocol-specific marker",
- or "the newest matching resource that is unlocked and assigned".

That is more composable than hard-wiring protocol-to-protocol calls.

## Two Different Places Metadata Lives

There are two closely related cases:

- tags on `RegRef` slots, added with `tag!`, which describe quantum resources;
- messages in a `MessageBuffer`, inserted with `put!`, which describe incoming
  classical communication.

The querying interface works across both, but the result shape is different:

- querying a register returns the matching `slot`, `id`, `tag`, and `time`;
- querying a message buffer returns the matching `src` and `tag`, plus an
  internal `depth` used when deleting the message.

## The Smallest Useful Workflow

```julia
tag!(reg[1], :ready, 7)
tag!(reg[2], :ready, 9)

query(reg, :ready, 7)
queryall(reg, :ready, ❓)
querydelete!(reg, :ready, 9)
```

This is the core composition pattern in QuantumSavory: produce metadata, query
for metadata, optionally consume it.

## Tag Shapes

The `Tag` type stores a small structured payload. Common patterns are:

- symbolic tags such as `Tag(:ready)` or `Tag(:swap_request)`;
- typed tags such as `Tag(EntanglementCounterpart, remote_node, remote_slot)`.

Typed tags are especially useful when several protocols share a common metadata
schema. They make the intended meaning explicit and allow custom printing.

## Wildcards And Predicates

Queries can match exactly, use a wildcard, or use a predicate for one field.

```julia
query(reg, :ready, ❓)
query(reg, EntanglementCounterpart, 7, ❓)
query(reg, :score, x -> x > 90)
```

This is the part that makes the metadata plane flexible. Protocols can agree on
the meaning of a tag without agreeing on one exact hard-coded lookup path.

## Register Queries Versus Message Queries

For registers:

- `query` returns the first match;
- `queryall` returns all matches;
- `querydelete!` returns one match and removes it.

For message buffers:

- `query` is available, but `querydelete!` is usually the useful operation,
  because classical messages are often consumed once handled.

If you want to wait until a match exists, use `query_wait` or
`querydelete_wait!` from the discrete-event layer.

## Filtering By Resource State

Register queries can also filter by slot state:

- `locked = true` or `false`,
- `assigned = true` or `false`.

That is important in networking protocols because metadata alone is not enough.
A slot may carry the right tag but still be unusable because it is already
reserved or empty.

## `Tag` Type

```@docs; canonical=false
QuantumSavory.Tag
```

The currently supported concrete tag signatures are:

```@example
using QuantumSavory #hide
[tuple(m.sig.types[2:end]...) for m in methods(Tag) if m.sig.types[2] ∈ (Symbol, DataType)]
```

## Assigning And Removing Tags

```@docs; canonical=false
QuantumSavory.tag!
QuantumSavory.untag!
```

## Querying

```@docs; canonical=false
query
```

## Wildcards

```@docs; canonical=false
W
❓
```

## `querydelete!`

`querydelete!` is the consuming form of `query`: it returns the first match and
removes it at the same time.

```@docs; canonical=false
querydelete!
```

## `queryall`

`queryall` returns every matching register tag.

```@docs; canonical=false
QuantumSavory.queryall
```

## Where To Go Next

- Read [Discrete Event Simulator](@ref sim) for `query_wait` and
  `querydelete_wait!`.
- Read [Backend Simulators](backendsimulator.md) and
  [Register Interface API](register_interface.md) for the quantum side of the
  same workflow.
