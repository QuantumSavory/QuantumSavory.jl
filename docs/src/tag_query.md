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
- typed tags such as `Tag(EntanglementCounterpart, remote_node, remote_slot, pair_id)`.

Typed tags are especially useful when several protocols share a common metadata
schema. They make the intended meaning explicit and allow custom printing.
`ProtocolZoo` defines a set of standard typed tags for interoperability with
its reusable protocols; see [Standard Protocol Tags](@ref
standard-protocol-tags).

### Named Tag Heads And `AbstractTag`

[`AbstractTag`](@ref) is the marker supertype for named tag heads used by
QuantumSavory protocols. It describes the type at the head of a stored `Tag`;
it does not replace the `Tag` sum type.

Custom tag heads passed as `EntanglerProt(...; tag=MyTag)` or
`EntanglementConsumer(...; tag=MyTag)` must be concrete subtypes of it:

```julia
struct MyTag <: AbstractTag end
```

This protocol-field contract does not restrict the generic metadata API.
`Tag(Int, 1)`, `Tag(MyOtherType, ...)`, and matching queries continue to accept
arbitrary `DataType` heads supported by the existing concrete tag signatures.

## Wildcards And Predicates

Queries can match exactly, use a wildcard, or use a predicate for one field.

```julia
query(reg, :ready, ❓)
query(reg, EntanglementCounterpart, 7, ❓, ❓)
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

## Consuming Register Tags In Protocols

Register query results are snapshots. They include a tag id and a slot, but
another process can run after any `@yield`, lock acquisition, timeout, or
message wait. By the time your protocol resumes, the tag may have been consumed
or the slot may have changed.

Use these rules in protocol code:

- use `querydelete!` or `querydelete_wait!` when the tag is meant to be consumed;
- do not carry a `query` or `queryall` result across a yield and then call
  `untag!` with the potentially outdated tag id;
- if you need to lock a slot before acting, acquire the lock and then re-query
  the slot before deleting the tag or using the result;
- for paired resources, re-check both sides before deleting either side (e.g. in an entanglement swapper that needs to lock two qubits).

`query_wait` is useful for observing that a matching tag exists. It is going to lock or reserve the tag it returns (or the register in which that tag is).

## Filtering By Resource State

Register queries can also filter by slot state:

- `locked = true` or `false`,
- `assigned = true` or `false`.

That is important in networking protocols because metadata alone is not enough.
A slot may carry the right tag but still be unusable because it is already
reserved or empty.

## `Tag` Type

```@docs; canonical=false
QuantumSavory.AbstractTag
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
- Read [Standard Protocol Tags](@ref standard-protocol-tags) for the typed tag
  schemas used by `ProtocolZoo`.
- Read [Backend Simulators](backendsimulator.md) and
  [Register Interface API](register_interface.md) for the quantum side of the
  same workflow.
