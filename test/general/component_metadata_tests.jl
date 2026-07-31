using Test
using QuantumSavory

struct CustomInspectableComponent
    value::Float64
end

QuantumSavory.constructor_schema(::Type{CustomInspectableComponent}) =
    ConstructorSchema(
        CustomInspectableComponent,
        "A test-only custom component.",
        (
            ConstructorFieldSchema(
                :value,
                Float64,
                "A constrained value.";
                required=true,
                minimum=0.0,
                maximum=1.0,
            ),
        ),
    )

@testset "Component metadata" begin
    @test slot_schemas() isa Tuple
    @test representation_schemas() isa Tuple
    @test background_schemas() isa Tuple

    @test map(schema -> schema.constructor, slot_schemas()) == (Qubit, Qumode)
    @test map(schema -> schema.constructor, representation_schemas()) ==
          (CliffordRepr, QuantumOpticsRepr, QuantumMCRepr)
    @test map(schema -> schema.constructor, background_schemas()) == (
        T1Decay,
        T2Dephasing,
        T1T2Noise,
        Depolarization,
        PauliNoise,
        AmplitudeDamping,
    )

    for schema in (
        slot_schemas()...,
        representation_schemas()...,
        background_schemas()...,
    )
        @test constructor_schema(schema.constructor) === schema
        @test !isempty(schema.doc)
        @test allunique(map(field -> field.name, schema.fields))
        @test schema.constructor(; map(
            field -> field.name => getfield(schema.constructor(), field.name),
            schema.fields,
        )...) isa schema.constructor
        for field in schema.fields
            @test field.declared_type === fieldtype(
                schema.constructor,
                field.name,
            )
            @test !isempty(field.doc)
        end
    end

    optics = constructor_schema(QuantumOpticsRepr)
    @test only(optics.fields).name === :cutoff
    @test !only(optics.fields).required
    @test constructor_constraints(QuantumOpticsRepr, Val(:cutoff)) ==
          (minimum=1, maximum=nothing)
    @test_throws ArgumentError constructor_constraints(
        QuantumOpticsRepr,
        Val(:unknown),
    )

    custom = constructor_schema(CustomInspectableComponent)
    @test custom.constructor === CustomInspectableComponent
    @test custom.fields[1].declared_type === Float64
    @test custom.fields[1].required
    @test constructor_constraints(
        CustomInspectableComponent,
        Val(:value),
    ) == (minimum=0.0, maximum=1.0)

    @test_throws ArgumentError ConstructorFieldSchema(
        :bad,
        Float64,
        "bad";
        required=false,
        minimum=2,
        maximum=1,
    )
    @test_throws UndefKeywordError ConstructorFieldSchema(
        :missing_required,
        Float64,
        "bad",
    )
    @test all(
        !field.required for schema in (
            slot_schemas()...,
            representation_schemas()...,
            background_schemas()...,
        ) for field in schema.fields
    )
    @test sum(
        length(schema.fields) for schema in (
            slot_schemas()...,
            representation_schemas()...,
            background_schemas()...,
        )
    ) == 10
    @test_throws ArgumentError constructor_schema(String)
    @test all(
        schema -> schema.constructor !== QuantumSavory.KrausAltWrapper,
        background_schemas(),
    )
end
