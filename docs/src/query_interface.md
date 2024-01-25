# Query Interface

```@meta
DocTestSetup =  quote
    using QuantumSavory
end
```


## `Tag`
Tags are identifiers which are used to represent classical information needed for a quantum information. The library allows the construction of custom tags following the format of one of the [`tag_types`](@ref) using the `Tag` constructor. The library implements the following tags for use in the networking protocols:

- `EntanglementCounterpart` 
    -`remote_node`
    -`remote_slot`
    It indicates the current entanglement status with a remote node's slot.

- `EntanglementHistory`
    - `remote_node`
    - `remote_slot`
    - `swap_remote_node`
    - `swap_remote_slot`
    - `swapped_local`
    This tag is used to store the outdated entanglement information after a swap. It helps to direct incoming entanglement update messages to the right node after a swap.

- `EntanglementUpdateX`
    - `past_local_node`
    - `past_local_slot`
    - `past_remote_slot`
    - `new_remote_node`
    - `new_remote_slot`
    - `correction`
    This tag arrives as a message from a remote node to which the current node was entangled to updat the entanglement information and apply an `X` correction after the remote node performs an entanglement swap.

- `EntanglementUpdateZ`
    - `past_local_node`
    - `past_local_slot`
    - `past_remote_slot`
    - `new_remote_node`
    - `new_remote_slot`
    - `correction`
    This tag arrives as a message from a remote node to which the current node was entangled to updat the entanglement information and apply a `Z` correction after the remote node performs an entanglement swap.

The tags are constructed using the `Tag` constructor
#### Tag(tagsymbol::Symbol, tagvariants...)
where `tagvariants` are the extra arguments required by the specific `tagsymbol`, for instance the `tag_types.SymbolIntInt` require two `Int` values. It supports the use of predicate functions (`Int -> Bool`) and [`Wildcard`](@ref) (❓) in place of the `tagvariants` which allows the user to perform queries for tags fulfilling certain criteria.

## `tag!`
Adds a `Tag` to the list of tags associated with a [`RegRef`](@ref) in a [`Register`](@ref)
#### `tag!(ref::RegRef, tag::Tag)`

## `untag!`
Removes the first matching tag from the list to tags associated with a [`RegRef`](@ref) in a [`Register`](@ref)
#### `untag!(ref::RegRef, tag::Tag)`

## [`query`](@ref)

[`query`](@ref) methods allow the user to query for `Tag`(s) in three different cases:
- on a particular qubit slot([`RegRef`](@ref)) in a [`Register`](@ref) node;
- on a [`Register`](@ref) to query for a slot that contains the passed `Tag`; and
- on a `MessageBuffer` to query for a particular `Tag` received from another node in a network.

The following features are supported:
- The query methods specialized on [`RegRef`](@ref) and [`Register`](@ref) allow for the queries to be executed in `FIFO` or `FILO` order, which is set to be `FIFO` by default. This means by default, a query on a [`RegRef`](@ref) returns the `Tag` which is at the end of the vector of tags attribute in a [`Register`](@ref), as new tags are pushed to the back by [`tag!`](@ref). On a [`Register`](@ref) it returns the slot number with the highest index having the queried `Tag`.

- The `Tag` passed to the method can be constructed using predicate functions (of the form: `Int` -> `Bool`) and [`Wildcard`](@ref) (❓). This supports querying for tags for which all the information is not known or isn't relevant, e.g, when looking for a qubit entangled with a neighbouring node in a repeater chain, we need a node that has a larger(right) or smaller(left) node number and the slot number of the neighbouring node to which its entangled is irrelevant. Hence, the `EntanglementCounterpart` tag passed to the [`query`](@ref) has a predicate `>(node)` or `<(node)` for `remote_node` and a [`Wildcard`](@ref) (❓) for `remote_slot` fields of the tag.

- It can be specified that the target slot be locked(or unlocked) and assigned(or unassigned) using the `locked` and `assigned` keywords which take `Bool` values. By default, the [`query`](@ref) does not check for these properties. This is available for [`query`](@ref) methods defined on [`Register`](@ref) and [`RegRef`](@ref).

#### `query(reg::Register, tag::Tag, ::Val{allB}=Val{false}(), ::Val{fifo}=Val{true}(); locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing)`

#### `query(ref::RegRef, tag::Tag, ::Val{allB}=Val{false}(), ::Val{fifo}=Val{true}())`

#### `query(mb::MessageBuffer, tag::Tag)`

## `querydelete!`
A method on top of [`query`](@ref) which allows to query for tag in a [`RegRef`](@ref) and `MessageBuffer` returning the tag that satisfies the passed predicates and [`Wildcard`](@ref)s and deleting it from the list at the same time. It allows the same arguments to be passed to it as the corresponding [`query`](@ref) method on the data structure its called upon.

#### `querydelete!(ref::RegRef, args...)`

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
    A["<code>querydelete!(ref::RegRef, args...)</code>"]
    B["<code>query(ref::RegRef, tag::Tag, ::Val{allB}=Val{false}(), ::Val{fifo}=Val{true}())</code>"]
    A --> B
</div>
```

#### `querydelete!(mb::MessageBuffer, args...)`

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
    A["<code>querydelete!(mb::MessageBuffer, args...)</code>"]
    B["<code>query(mb::MessageBuffer, tag::Tag)</code>"]
    A --> B
</div>
```

## `queryall`
A method defined on top of [`query`](@ref) which allows to query for all tags in a [`RegRef`](@ref) or a [`Register`](@ref) that match the passed `Tag`, instead of just one matching instance.

#### `queryall(args...; kwargs...)`

where `args...` and `kwargs...` correspond to the arguments and keyword arguments accepted by the [`query`](@ref) method on the particular data structure on which the method is called upon.

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
    A["<code>queryall(args...; kwargs...)</code>"]
    B["<code>query(args..., ::Val{allB}=Val{true}(), ::Val{fifo}=Val{true}; kwargs...)</code>"]
</div>
```