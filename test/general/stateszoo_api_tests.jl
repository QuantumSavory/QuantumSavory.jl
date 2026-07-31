using Test
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW
using QuantumOpticsBase
using LinearAlgebra

struct CustomMetadataState <: QuantumSavory.StatesZoo.AbstractTwoQubitState
    x::Float64
end

QuantumSavory.StatesZoo.state_family_schema(::Type{CustomMetadataState}) =
    StateFamilySchema(
        CustomMetadataState,
        "A test-only normalized state family.",
        (
            StateParameterSchema(
                :x,
                Float64,
                "A test parameter.",
                0.0,
                1.0,
                0.5,
            ),
        ),
        NormalizedState,
    )

LinearAlgebra.tr(::CustomMetadataState) = 1.0

struct UnregisteredMetadataState <:
       QuantumSavory.StatesZoo.AbstractTwoQubitState end

@testset "StatesZoo API" begin

_evalf(x::Number) = x
_evalf(x) = express(x)

expected_families = (
    BarrettKokBellPair,
    BarrettKokBellPairW,
    DepolarizedBellPair,
    GenqoMultiplexedCascadedBellPairW,
    GenqoUnheraldedSPDCBellPairW,
)
expected_normalization = (
    NormalizedState,
    WeightedState,
    NormalizedState,
    WeightedState,
    WeightedState,
)

schemas = state_family_schemas()
@test schemas isa Tuple
@test map(schema -> schema.family, schemas) == expected_families
@test map(schema -> schema.normalization, schemas) ==
      expected_normalization

for schema in schemas
    S = schema.family
    @test state_family_schema(S) === schema
    @test state_normalization_style(S) === schema.normalization
    @test !isempty(schema.doc)
    @test allunique(map(parameter -> parameter.name, schema.parameters))
    @test all(parameter -> !isempty(parameter.doc), schema.parameters)

    params = QuantumSavory.StatesZoo.stateparameters(S)
    paramdict = QuantumSavory.StatesZoo.stateparametersrange(S)
    @test params == map(parameter -> parameter.name, schema.parameters)
    @test paramdict == NamedTuple{params}(map(schema.parameters) do parameter
        (
            min=parameter.minimum,
            max=parameter.maximum,
            good=parameter.recommended,
        )
    end)
    @test all(
        parameter -> parameter.recommended isa parameter.value_type,
        schema.parameters,
    )

    state = S((paramdict[p].good for p in params)...)
    @test state_family_schema(state) === schema
    @test state_normalization_style(state) === schema.normalization

    reg = Register(2)
    initialize!(reg[1:2], state)
    @test ! iszero(observable(reg[1:2], Z⊗Z))
    @test _evalf(tr(state)) ≈ tr(express(state))

    weight = state_weight(state)
    normalized = normalized_state_and_weight(state)
    @test normalized.weight ≈ weight
    @test tr(express(normalized.state)) ≈ 1
    if schema.normalization === NormalizedState
        @test normalized.state === state
        @test weight ≈ 1
    else
        @test normalized.state !== state
        @test tr(express(state)) ≈ weight
        @test !(weight ≈ 1)
    end
end

custom = state_family_schema(CustomMetadataState)
@test custom.family === CustomMetadataState
@test stateparameters(CustomMetadataState) == (:x,)
@test stateparametersrange(CustomMetadataState) ==
      (x=(min=0.0, max=1.0, good=0.5),)
@test normalized_state_and_weight(CustomMetadataState(0.25)) ==
      (state=CustomMetadataState(0.25), weight=1.0)
@test map(schema -> schema.family, state_family_schemas()) ==
      expected_families

zero_weight = BarrettKokBellPairW(0, 0, 0, 1, 1)
@test state_weight(zero_weight) == 0
@test_throws DomainError normalized_state_and_weight(zero_weight)
@test_throws DomainError state_weight(
    BarrettKokBellPairW(1, 1, NaN, 1, 1),
)

@test stateparameters(Int) == ()
@test stateparametersrange(Int) == ()
@test_throws ArgumentError state_family_schema(UnregisteredMetadataState)
@test_throws ArgumentError stateparameters(UnregisteredMetadataState)

@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Bool,
    "Invalid.",
    0,
    1,
    1,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Real,
    "Invalid.",
    1,
    0,
    0,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Real,
    "Invalid.",
    0,
    1,
    2,
)
@test_throws ArgumentError StateFamilySchema(
    Int,
    "Invalid.",
    (),
    NormalizedState,
)
duplicate_parameter = StateParameterSchema(
    :duplicate,
    Real,
    "Duplicate.",
    0,
    1,
    0,
)
@test_throws ArgumentError StateFamilySchema(
    CustomMetadataState,
    "Invalid.",
    (duplicate_parameter, duplicate_parameter),
    NormalizedState,
)

end
