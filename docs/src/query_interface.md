# Query Interface

```@meta
DocTestSetup =  quote
    using QuantumSavory
end
```
The query interface allows us to use various quantum networking protocols defined in QuantumSavory together in a simulation. It provides composability between the various protocols where each protocol can operate independently of the other without knowing its internals. This is done by using various tags to communicate metadata between the network nodes running the protocols. This leads to greater flexibility when setting up different simulations since the information about how the nodes running the protocols should interact is generally defined in the protocols and the specifics at runtime are determined by the tags passed and received.

The following lines explain in detail, the components of the query interface which make this possible.

## `Tag`
Tags are used to represent classical metadata describing the state and history of the nodes. The library allows the construction of custom tags following the format of one of the [`tag_types`](@ref) using the `Tag` constructor. The library implements the following tags for use in the networking protocols:

```@docs
QuantumSavory.ProtocolZoo.EntanglementCounterpart
QuantumSavory.ProtocolZoo.EntanglementHistory
QuantumSavory.ProtocolZoo.EntanglementUpdateX
QuantumSavory.ProtocolZoo.EntanglementUpdateZ
```

The tags are constructed using the `Tag` constructor
#### Tag(tagsymbol::Symbol, tagvariants...)
where `tagvariants` are the extra arguments required by the specific `tagsymbol`, for instance the `tag_types.SymbolIntInt` require two `Int` values. It supports the use of predicate functions (`Int -> Bool`) and [`Wildcard`](@ref) (❓) in place of the `tagvariants` which allows the user to perform queries for tags fulfilling certain criteria.

## `tag!`
```@docs
QuantumSavory.tag!
```

## `untag!`
```@docs
QuantumSavory.untag!
```

## [`query`](@ref)

[`query`](@ref) function allow the user to query for `Tag`(s) in three different cases:
- on a particular qubit slot([`RegRef`](@ref)) in a [`Register`](@ref) node;
- on a [`Register`](@ref) to query for a slot that contains the passed `Tag`; and
- on a `MessageBuffer` to query for a particular `Tag` received from another node in a network.

The following features are supported:
- The query methods specialized on [`RegRef`](@ref) and [`Register`](@ref) allow for the queries to be executed in `FIFO` or `FILO` order, which is set to be `FIFO` by default. This means by default, a query on a [`RegRef`](@ref) returns the `Tag` which is at the end of the vector of tags attribute in a [`Register`](@ref), as new tags are pushed to the back by [`tag!`](@ref). On a [`Register`](@ref) it returns the slot number with the highest index having the queried `Tag`.

- The `Tag` passed to the method can be constructed using predicate functions (of the form: `Int` -> `Bool`) and [`Wildcard`](@ref) (❓). This supports querying for tags for which all the information is not known or isn't relevant, e.g, when looking for a qubit entangled with a neighbouring node in a repeater chain, we need a node that has a larger(right) or smaller(left) node number and the slot number of the neighbouring node to which its entangled is irrelevant. Hence, the `EntanglementCounterpart` tag passed to the [`query`](@ref) has a predicate `>(node)` or `<(node)` for `remote_node` and a [`Wildcard`](@ref) (❓) for `remote_slot` fields of the tag.

- It can be specified that the target slot be locked(or unlocked) and assigned(or unassigned) using the `locked` and `assigned` keywords which take `Bool` values. By default, the [`query`](@ref) does not check for these properties. This is available for [`query`](@ref) methods defined on [`Register`](@ref) and [`RegRef`](@ref).

Following is a detailed description of each `query` methods

```@docs
query(::Register,::Tag,::Val{Bool})
```

```@docs
query(::RegRef,::Tag,::Val{Bool}) 
```

```@docs
query(::QuantumSavory.MessageBuffer,::Tag)
```

## `querydelete!`
A method on top of [`query`](@ref) which allows to query for tag in a [`RegRef`](@ref) and `MessageBuffer` returning the tag that satisfies the passed predicates and [`Wildcard`](@ref)s and deleting it from the list at the same time. It allows the same arguments to be passed to it as the corresponding [`query`](@ref) method on the data structure its called upon.

```@docs
querydelete!(::QuantumSavory.MessageBuffer,args...)
```

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
    A["<code>querydelete!(mb::MessageBuffer, args...)</code>"]
    B["<code>query(mb::MessageBuffer, tag::Tag)</code>"]
    A --> B
</div>
```

```@docs
querydelete!(::RegRef, args...)
```

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
    A["<code>querydelete!(ref::RegRef, args...)</code>"]
    B["<code>query(ref::RegRef, tag::Tag, ::Val{allB}=Val{false}(), ::Val{fifo}=Val{true}())</code>"]
    A --> B
</div>
```


## `queryall`
A method defined on top of [`query`](@ref) which allows to query for all tags in a [`RegRef`](@ref) or a [`Register`](@ref) that match the passed `Tag`, instead of just one matching instance.

```@docs
QuantumSavory.queryall
```

#### Interface Overview

```@raw html
<div class="mermaid">
flowchart TB
    A["<code>queryall(args...; kwargs...)</code>"]
    B["<code>query(args..., ::Val{allB}=Val{true}(), ::Val{fifo}=Val{true}; kwargs...)</code>"]
</div>
```