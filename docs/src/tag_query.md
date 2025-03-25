# [Tagging and Querying](@id tagging-and-querying)

The [`query`](@ref) and [`tag!`](@ref) interface lets you manage "classical state" metadata in your simulations. In particular, this interface enables the creation of modular interoperable [control protocols](@ref "Predefined Networking Protocols"). Each protocol can operate independently of others without knowledge of each others' internals. This is done by using various "tags" to communicate metadata between the network nodes running the protocols, and by the protocols querying for the presence of such tags, leading to greater flexibility when setting up different simulations.

The components of the query interface which make this possible are described below.

## The `Tag` type

```@docs; canonical=false
QuantumSavory.Tag
```

And here are all currently supported tag signatures:

```@example
using QuantumSavory #hide
[tuple(m.sig.types[2:end]...) for m in methods(Tag) if m.sig.types[2] ∈ (Symbol, DataType)]
```

## Assigning and removing tags

```@docs; canonical=false
QuantumSavory.tag!
QuantumSavory.untag!
```

## Querying for the presence of a tag

The [`query`](@ref) function allows the user to query for [`Tag`](@ref)s in three different cases:
- on a particular qubit slot ([`RegRef`](@ref)) in a [`Register`](@ref) node;
- on a [`Register`](@ref) to query for any slot that contains the passed `Tag`;
- on a [`messagebuffer`](@ref) to query for a particular `Tag` received from another node in a network.

The `Tag` description passed to `query` can include predicate functions (of the form `x -> pass::Bool`) and wildcards (the [`❓`](@ref) variable), for situations where we have freedom in what tag we are exactly searching for.

The queries can search in `FIFO` or `FILO` order (`FILO` by default). E.g., for the default `FILO`, a query on a [`RegRef`](@ref) returns the `Tag` which is at the end of the vector of tags stored the given slot (as new tags are appended at the end). On a [`Register`](@ref) it returns the slot with the "youngest" age.

One can also query by "lock" and "assignment" status of a given slot, by using the `locked` and `assigned` boolean keywords. By default these keywords are set to `nothing` and these properties are not checked.

Following is a detailed description of each `query` method

```@docs; canonical=false
query
```

### Wildcards

```@docs; canonical=false
W
❓
```

### `querydelete!`

A method on top of [`query`](@ref), which allows to query for tag in a [`RegRef`](@ref) or a [`messagebuffer`](@ref), returning the tag that satisfies the passed predicates and wildcars, **and deleting it from the list at the same time**. It otherwise has the same signature as [`query`](@ref).

```@docs; canonical=false
querydelete!
```

### `queryall`
A method defined on top of [`query`](@ref) which allows to query for **all tags** in a [`RegRef`](@ref) or a [`Register`](@ref) that match the query.

```@docs; canonical=false
QuantumSavory.queryall
```