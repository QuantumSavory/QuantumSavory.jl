# Component Metadata

QuantumSavory exposes typed, simulator-owned metadata for the components that
can be selected when constructing registers. This is the stable discovery
surface for editors, configuration tools, and other packages that need to
present constructor choices without inspecting Julia's type hierarchy or
documentation internals.

## Built-in Catalogs

The three catalogs are explicit and deterministic:

```@example component-metadata
using QuantumSavory

map(schema -> schema.constructor, slot_schemas())
```

```@example component-metadata
map(schema -> schema.constructor, representation_schemas())
```

```@example component-metadata
map(schema -> schema.constructor, background_schemas())
```

Every entry is a [`ConstructorSchema`](@ref). Its ordered `fields` are
[`ConstructorFieldSchema`](@ref) values containing the declared Julia type,
documentation, required-keyword status, and any inclusive numeric bounds owned
by the simulator.

```@example component-metadata
schema = constructor_schema(QuantumOpticsRepr)
field = only(schema.fields)
(field.name, field.declared_type, field.required, constructor_constraints(
    QuantumOpticsRepr,
    Val(:cutoff),
))
```

`required=true` means that callers must supply the advertised keyword.
`required=false` means that callers may omit it and let the constructor apply
its simulator-owned default. Requiredness is unrelated to whether the declared
type accepts `Nothing`: an optional keyword may reject `nothing`, while a
required keyword may accept it.

Constructor metadata deliberately does not contain default values. Consumers
should preserve omission for optional fields instead of copying or serializing
defaults that belong to QuantumSavory.

An absent bound is represented by `nothing`; consumers should not invent a
constraint when QuantumSavory does not declare one. The catalogs contain
public modeling components only, not backend implementation helpers.

## Protocol Catalog

Protocol discovery uses the same explicit-schema approach:

```@example component-metadata
using QuantumSavory.ProtocolZoo

map(schema -> (
    protocol=schema.constructor.constructor,
    placement=schema.placement,
), protocol_schemas())
```

Each [`ProtocolSchema`](@ref) separates user-configurable constructor fields
from injected simulation, network, placement, and private runtime fields.
`placement_fields` identifies the node field or ordered edge fields. An edge
schema also records whether that protocol can intentionally operate without a
physical graph edge.

```@example component-metadata
schema = protocol_schema(EntanglementConsumer)
(
    protocol_placement(EntanglementConsumer),
    schema.placement_fields,
    permits_virtual_edge(EntanglementConsumer),
)
```

Custom protocols expose all three facts by extending `protocol_schema`;
`protocol_placement` and `permits_virtual_edge` derive from that one schema.
An unregistered custom protocol is not introspectable. Defining a custom
subtype never changes the deterministic built-in `protocol_schemas()` catalog.

## Extending Constructor Metadata

A package that defines a custom component can add a
`constructor_schema(::Type{MyComponent})` method. Explicit registration is
intentional: merely loading a package or defining a subtype must not silently
change QuantumSavory's built-in catalogs.

```julia
Base.@kwdef struct MyBackground <: AbstractBackground
    rate::Float64
end

QuantumSavory.constructor_schema(::Type{MyBackground}) = ConstructorSchema(
    MyBackground,
    "A custom background process.",
    (
        ConstructorFieldSchema(
            :rate,
            Float64,
            "Event rate.";
            required=true,
            minimum=0.0,
        ),
    ),
)
```

```@docs; canonical=false
ConstructorFieldSchema
ConstructorSchema
constructor_schema
constructor_constraints
slot_schemas
representation_schemas
background_schemas
ProtocolPlacement
ProtocolSchema
protocol_schema
protocol_placement
protocol_schemas
```
