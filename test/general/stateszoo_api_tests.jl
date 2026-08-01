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

function _is_usable_state(schema, values)
    try
        state = schema.family(values...)
        density_matrix = express(state)
        trace_value = tr(density_matrix)
        return all(isfinite, density_matrix.data) &&
               isfinite(trace_value) &&
               abs(trace_value) > 0
    catch
        return false
    end
end

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
expected_parameters = (
    (:ηᴬ, :ηᴮ, :Pᵈ, :ηᵈ, :𝒱, :m),
    (:ηᴬ, :ηᴮ, :Pᵈ, :ηᵈ, :𝒱, :m),
    (:p,),
    (:ηᵇ, :ηᵈ, :ηᵗ, :N),
    (:ηᵈ, :ηᵗ, :N),
)

schemas = state_family_schemas()
@test schemas isa Tuple
@test map(schema -> schema.family, schemas) == expected_families
@test map(schema -> schema.normalization, schemas) ==
      expected_normalization
@test map(
    schema -> map(parameter -> parameter.value_type, schema.parameters),
    schemas,
) == (
    (Float64, Float64, Float64, Float64, Float64, Int),
    (Float64, Float64, Float64, Float64, Float64, Int),
    (Float64,),
    (Float64, Float64, Float64, Float64),
    (Float64, Float64, Float64),
)

for (schema, expected_parameter_names) in zip(schemas, expected_parameters)
    S = schema.family
    @test state_family_schema(S) === schema
    @test state_normalization_style(S) === schema.normalization
    @test !isempty(schema.doc)
    @test allunique(map(parameter -> parameter.name, schema.parameters))
    @test all(parameter -> !isempty(parameter.doc), schema.parameters)

    params = map(parameter -> parameter.name, schema.parameters)
    @test params == expected_parameter_names
    @test all(
        parameter -> parameter.recommended isa parameter.value_type,
        schema.parameters,
    )
    @test all(
        parameter -> parameter.recommended in parameter,
        schema.parameters,
    )
    @test all(schema.parameters) do parameter
        values = state_parameter_values(parameter, 30)
        !isempty(values) && length(values) <= 30 &&
            all(value -> value in parameter, values)
    end

    state = S((parameter.recommended for parameter in schema.parameters)...)
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

    recommended = map(parameter -> parameter.recommended, schema.parameters)
    for (index, parameter) in pairs(schema.parameters)
        @testset "$(schema.family).$(parameter.name) endpoints" begin
            for (endpoint, included) in (
                (parameter.minimum, parameter.minimum_inclusive),
                (parameter.maximum, parameter.maximum_inclusive),
            )
                values = collect(recommended)
                values[index] = endpoint
                @test (endpoint in parameter) === included
                @test _is_usable_state(schema, values) === included
            end
        end
    end
end

@test filter(!=(:metadata), fieldnames(GenqoMultiplexedCascadedBellPairW)) ==
      (:ηᵇ, :ηᵈ, :ηᵗ, :N)
@test filter(!=(:metadata), fieldnames(GenqoUnheraldedSPDCBellPairW)) ==
      (:ηᵈ, :ηᵗ, :N)
@test_throws MethodError GenqoMultiplexedCascadedBellPairW(1, 1, 1, 0.1, 0)
@test_throws MethodError GenqoUnheraldedSPDCBellPairW(1, 1, 0.1, 0)

for (low_mean_photon_number, high_mean_photon_number) in (
    (
        GenqoMultiplexedCascadedBellPairW(1, 1, 1, 0.05),
        GenqoMultiplexedCascadedBellPairW(1, 1, 1, 0.15),
    ),
    (
        GenqoUnheraldedSPDCBellPairW(1, 1, 0.05),
        GenqoUnheraldedSPDCBellPairW(1, 1, 0.15),
    ),
)
    low_matrix = express(low_mean_photon_number).data
    high_matrix = express(high_mean_photon_number).data
    @test norm(low_matrix - high_matrix) > 1e-3
end

custom = state_family_schema(CustomMetadataState)
@test custom.family === CustomMetadataState
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

@test_throws ArgumentError state_family_schema(UnregisteredMetadataState)

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
    Rational{Int},
    "Invalid.",
    0 // 1,
    1 // 1,
    1 // 2,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    UInt,
    "Invalid.",
    UInt(0),
    UInt(1),
    UInt(0),
)
huge_integer = big(10)^400
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    BigInt,
    "Invalid.",
    huge_integer,
    huge_integer,
    huge_integer,
)
narrow_denominator = big(2)^60
narrow_minimum = (narrow_denominator + 1) // narrow_denominator
narrow_maximum = narrow_minimum + 1 // narrow_denominator
narrow_recommended = (narrow_minimum + narrow_maximum) / 2
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Real,
    "Invalid.",
    narrow_minimum,
    narrow_maximum,
    narrow_recommended,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    AbstractFloat,
    "Invalid.",
    0.0,
    1.0,
    0.5,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Float64,
    "Invalid.",
    1.0,
    0.0,
    0.0,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Float64,
    "Invalid.",
    0.0,
    1.0,
    2.0,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Float64,
    "Invalid.",
    0,
    1,
    0.5,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Float64,
    "Invalid.",
    0.0,
    1.0,
    0.0,
    minimum_inclusive=false,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Float64,
    "Invalid.",
    0.0,
    1.0,
    1.0,
    maximum_inclusive=false,
)
@test_throws ArgumentError StateParameterSchema(
    :invalid,
    Float64,
    "Invalid.",
    0.0,
    0.0,
    0.0,
    minimum_inclusive=false,
)
open_parameter = StateParameterSchema(
    :open,
    Float64,
    "Open.",
    0.0,
    1.0,
    0.5,
    minimum_inclusive=false,
    maximum_inclusive=false,
)
@test 0.0 ∉ open_parameter
@test 0.5 ∈ open_parameter
@test 1.0 ∉ open_parameter
@test -0.1 ∉ open_parameter
@test 1.1 ∉ open_parameter
@test true ∉ open_parameter
@test NaN ∉ open_parameter
@test Inf ∉ open_parameter
@test 1 ∉ open_parameter
@test length(state_parameter_values(open_parameter, 30)) == 30
@test state_parameter_values(open_parameter, 1) == [0.5]
float32_parameter = StateParameterSchema(
    :float32,
    Float32,
    "Float32.",
    0.0f0,
    1.0f0,
    0.5f0,
)
float32_values = state_parameter_values(float32_parameter, 3)
@test all(value -> value isa Float32, float32_values)
@test all(value -> value in float32_parameter, float32_values)
@test state_parameter_values(float32_parameter, 1) == [0.5f0]
bigfloat_parameter = StateParameterSchema(
    :bigfloat,
    BigFloat,
    "BigFloat.",
    BigFloat(0),
    BigFloat(1),
    BigFloat(0.5),
)
bigfloat_values = state_parameter_values(bigfloat_parameter, 3)
@test eltype(bigfloat_values) === BigFloat
@test length(bigfloat_values) == 3
@test all(value -> value in bigfloat_parameter, bigfloat_values)
@test state_parameter_values(bigfloat_parameter, 1) == [BigFloat(0.5)]
overflowing_span_parameter = StateParameterSchema(
    :overflowing_span,
    Float64,
    "Finite bounds with an overflowing span.",
    -floatmax(Float64),
    floatmax(Float64),
    0.0,
)
@test state_parameter_values(overflowing_span_parameter, 30) == [0.0]
integer_parameter = StateParameterSchema(
    :integer,
    Int,
    "Integer.",
    0,
    10,
    5,
)
@test state_parameter_values(integer_parameter, 30) == collect(0:10)
@test state_parameter_values(integer_parameter, 3) == [0, 5, 10]
@test all(value -> value isa Int, state_parameter_values(integer_parameter, 3))
maximum_integer_parameter = StateParameterSchema(
    :maximum_integer,
    Int,
    "Maximum integer singleton.",
    typemax(Int),
    typemax(Int),
    typemax(Int),
)
@test state_parameter_values(maximum_integer_parameter, 30) == [typemax(Int)]
full_integer_parameter = StateParameterSchema(
    :full_integer,
    Int,
    "Full machine-integer interval.",
    typemin(Int),
    typemax(Int),
    0,
)
@test state_parameter_values(full_integer_parameter, 3) ==
      [typemin(Int), 0, typemax(Int)]
full_integer_values = state_parameter_values(full_integer_parameter, 30)
@test length(full_integer_values) == 30
@test issorted(full_integer_values)
@test allunique(full_integer_values)
@test all(value -> value in full_integer_parameter, full_integer_values)
@test_throws ArgumentError state_parameter_values(integer_parameter, 0)
@test_throws ArgumentError state_parameter_values(integer_parameter, true)
@test_throws ArgumentError state_parameter_values(
    integer_parameter,
    big(typemax(Int)) + 1,
)
@test_throws ArgumentError StateFamilySchema(
    Int,
    "Invalid.",
    (),
    NormalizedState,
)
duplicate_parameter = StateParameterSchema(
    :duplicate,
    Float64,
    "Duplicate.",
    0.0,
    1.0,
    0.0,
)
@test_throws ArgumentError StateFamilySchema(
    CustomMetadataState,
    "Invalid.",
    (duplicate_parameter, duplicate_parameter),
    NormalizedState,
)

end
