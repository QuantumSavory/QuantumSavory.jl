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
documentation, and any inclusive numeric bounds owned by the simulator.

```@example component-metadata
schema = constructor_schema(QuantumOpticsRepr)
field = only(schema.fields)
(field.name, field.declared_type, constructor_constraints(
    QuantumOpticsRepr,
    Val(:cutoff),
))
```

An absent bound is represented by `nothing`; consumers should not invent a
constraint when QuantumSavory does not declare one. The catalogs contain
public modeling components only, not backend implementation helpers.

## Extending Constructor Metadata

A package that defines a custom component can add a
`constructor_schema(::Type{MyComponent})` method. Explicit registration is
intentional: merely loading a package or defining a subtype must not silently
change QuantumSavory's built-in catalogs.

```julia
struct MyBackground <: AbstractBackground
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
```
