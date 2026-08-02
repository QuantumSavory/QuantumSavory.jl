# Predefined Networking Protocols

```@raw html
<style>
    .content table td {
        padding-top: 0 !important;
        padding-bottom: 0 !important;
    }
</style>
```

The submodule `QuantumSavory.ProtocolZoo` provides reusable networking
protocols, including their discrete-event control flow.

## What ProtocolZoo Is For

`ProtocolZoo` contains ready-to-run protocol components such as entanglers,
swappers, trackers, consumers, and switch-like controllers.

These are not just code samples. They are structured `AbstractProtocol`
implementations meant to be launched inside a simulation with `@process`.

```julia
prot = EntanglerProt(sim, net, 1, 2)
@process prot()
```

This matters because the protocol object packages:

- the simulation handle,
- the network it acts on,
- the node or nodes it belongs to,
- and the parameters controlling its behavior.

That packaging is what makes protocols easier to reuse and compare than a large
free function with many arguments.

When user-written protocols need to cooperate with these implementations, the
main interface is the standard set of typed tags documented in
[Standard Protocol Tags](@ref standard-protocol-tags).

`EntanglerProt` and `EntanglementConsumer` accept a named tag-head type through
their `tag` fields. Custom types supplied there must be concrete subtypes of
`QuantumSavory.AbstractTag`; the entangler additionally accepts `nothing` to
disable tagging. This marker describes the head stored inside a `Tag` and does
not replace the `Tag` value itself.

## How Protocols Compose

Protocols in `ProtocolZoo` are designed to compose through the same metadata and
messaging interfaces available to user-written code.

In practice, that means one protocol can:

- generate entanglement and tag the resulting slots,
- another protocol can query those tags and perform a swap,
- and a tracker or consumer can react to the resulting metadata updates.

This is the practical point of the protocol layer: reusable control logic that
does not depend on bespoke peer-to-peer wiring.

## Opting Into the Interactive Protocol Catalog

The public, non-exported
`QuantumSavory.ProtocolZoo.available_protocol_types` function supplies the
protocol catalog used by interactive and Web tooling. Load `InteractiveUtils`
and `REPL` to activate it. The function recursively discovers concrete public
subtypes of `AbstractProtocol` in every loaded package, but a protocol appears
only when its package explicitly extends the public
`protocol_catalog_metadata` trait for that type. There is no registry or
initialization hook, and a package loaded later is visible on the next call.

Here is a minimal independent-package definition:

```julia
module MyProtocolPackage

using ConcurrentSim: Simulation
using QuantumSavory: RegisterNet
using QuantumSavory.ProtocolZoo: AbstractProtocol
import QuantumSavory.ProtocolZoo: permits_virtual_edge, protocol_catalog_metadata

public MyProtocol

"""A protocol attached to one network node."""
Base.@kwdef struct MyProtocol <: AbstractProtocol
    "the simulation supplied by the framework"
    sim::Simulation
    "the register network supplied by the framework"
    net::RegisterNet
    "the topology-supplied host node"
    host::Int
    "the configurable target nodes"
    targets::Vector{Int}
    "optional retry delay"
    retry_delay::Float64 = 0.1
    _cache::Vector{Int} = Int[]
end

protocol_catalog_metadata(::Type{MyProtocol}) = (
    attachment = :node,
    attachment_fields = (node=:host,),
    required_fields = (:targets,),
)

permits_virtual_edge(::Type{MyProtocol}) = true

end
```

The trait result must be a named tuple with exactly the following keys, in this
order:

- `attachment` is `:network`, `:node`, or `:edge`;
- `attachment_fields` maps topology roles to constructor fields. The mapping is
  respectively empty, `(node=:field,)`, or
  `(node_a=:field_a, node_b=:field_b)`. Mapped fields must be distinct and
  documented; and
- `required_fields` is a tuple of distinct configurable fields that have no
  catalog-supplied value.

Cataloged protocols follow the `sim`/`net` convention: both injected fields and
every other non-underscore field must be documented. The topology mapping
supplies attachment fields, while all remaining non-private fields become
`parameters`. Each parameter descriptor contains `(field, type, doc, required)`.
The protocol descriptor contains
`(type, doc, nodeargs, attachment, attachment_fields, parameters,
permits_virtual_edge)`, with `nodeargs` derived from the number of attachment
fields. Underscore-prefixed runtime storage is never configurable.

The canonical defining binding must be public (declared with `public` or
`export`). Re-exporting a private-origin type does not opt it in, and aliases or
re-exports do not duplicate an already-public type. Current MBQC implementation
types deliberately remain outside this catalog until they add trait methods.

## Protocol Logging Context

ProtocolZoo records use Julia's standard logging macros and the public
[`protocol_log_context`](@ref) helper. The helper returns simulation time,
active process id, protocol type name, and an ordered tuple of participating
nodes. Custom `AbstractProtocol` implementations should overload it when their
node layout is not already represented:

```julia
import QuantumSavory.ProtocolZoo: protocol_log_context

protocol_log_context(prot::MyProtocol) = (
    simulation_log_context(prot.sim)...,
    protocol=:MyProtocol,
    nodes=(prot.node,),
)

@debug(
    "Consumed entanglement",
    _group=LOG_GROUPS.protocol,
    event=:entanglement_consumed,
    protocol_log_context(prot)...,
    slots=(left_slot, right_slot),
    pair_id=pair_id,
)
```

Keep selectors and runtime peers out of the base `nodes` tuple. Put the actual
participants for one event in fields such as `src_node`, `dst_node`, or
`remote_nodes`.

## Visualization Hooks

Some protocols also expose richer visualization through `show` methods.
`EntanglerProt`, for example, can render protocol-specific summaries in HTML or
PNG form.

Those displays are not part of the protocol logic itself, but they are useful
for debugging configuration and inspecting the expected behavior of a protocol
before embedding it into a larger simulation.

## Typical Contents

The current `ProtocolZoo` includes:

- entanglement generation and swapping protocols,
- metadata tracking helpers,
- consumer and cutoff protocols,
- switch-style protocols,
- and QTCP-related controllers and message types.

The autodocs below are the exact API reference.

## Autogenerated API list for `QuantumSavory.ProtocolZoo`

```@autodocs
Modules = [QuantumSavory.ProtocolZoo, QuantumSavory.ProtocolZoo.Switches, QuantumSavory.ProtocolZoo.QTCP, QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation]
Private = false
```
