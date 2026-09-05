# [API Autodiscovery](@id api-autodiscovery)

QuantumSavory provides runtime catalogs for tools, like GUIs, that need all the models and
protocols available in the current Julia process. A primary consumer is the
[QuantumSavory Web GUI](https://gui.quantumsavory.org), developed in the
[WebQuantumSavory repository](https://github.com/QuantumSavory/WebQuantumSavory).

Load the `InteractiveUtils` and `REPL` standard libraries to activate these APIs:

```julia
using QuantumSavory
using InteractiveUtils
using REPL
```

## Slots, Backgrounds, and Constructors

The public, non-exported functions
`QuantumSavory.available_slot_types` and
`QuantumSavory.available_background_types` return `(type, doc)` entries.
`QuantumSavory.constructor_metadata(T)` returns `(field, type, doc)` entries and omits
undocumented or underscore-prefixed fields. Types with convenience constructors that
differ from their storage layout can specialize this metadata for those constructors.

The type catalogs recursively discover concrete subtypes from every currently loaded
package and retain usable parametric constructors. A type is included only when its
canonical defining binding is public. Results are recomputed and sorted by qualified
type name on every call, so loading another package updates the next result immediately.
Re-exporting a private-origin type does not make it discoverable, and aliases or
re-exports do not duplicate an already-public type.

## Protocols

The public, non-exported
`QuantumSavory.ProtocolZoo.available_protocol_types` function returns the protocol
catalog used by interactive and Web tooling. It discovers concrete public subtypes of
`AbstractProtocol`, but includes a protocol only when its package explicitly extends
the public `protocol_catalog_metadata` trait for that type. There is no registry or
initialization hook.

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

The trait result must be a named tuple with exactly the following keys, in this order:

- `attachment` is `:network`, `:node`, or `:edge`;
- `attachment_fields` maps topology roles to constructor fields. The mapping is
  respectively empty, `(node=:field,)`, or
  `(node_a=:field_a, node_b=:field_b)`. Mapped fields must be distinct and documented;
  and
- `required_fields` is a tuple of distinct configurable fields that have no
  catalog-supplied value.

Cataloged protocols follow the `sim`/`net` convention: both injected fields and every
other non-underscore field must be documented. The topology mapping supplies attachment
fields, while all remaining non-private fields become `parameters`. Each parameter
descriptor contains `(field, type, doc, required)`. The protocol descriptor contains
`(type, doc, nodeargs, attachment, attachment_fields, parameters,
permits_virtual_edge)`, with `nodeargs` derived from the number of attachment fields.
Underscore-prefixed runtime storage is never configurable.

Current MBQC implementation types remain outside this catalog until they add trait
methods.
