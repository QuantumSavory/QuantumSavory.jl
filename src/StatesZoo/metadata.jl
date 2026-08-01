"""
    StateNormalizationStyle

Whether a StatesZoo family represents a normalized density matrix or a
weighted density matrix whose trace carries a success weight.
"""
@enum StateNormalizationStyle::UInt8 begin
    NormalizedState
    WeightedState
end

"""
    StateParameterSchema

Stable metadata for one ordered, real-valued StatesZoo parameter.

`minimum` and `maximum` are the exact interval boundaries.
`minimum_inclusive` and `maximum_inclusive` state whether each boundary is
part of the interval. `recommended` is the default point used by explorers and
examples. Use `value in parameter_schema` to validate a value against its type
and interval.
"""
struct StateParameterSchema
    name::Symbol
    value_type::Type
    doc::String
    minimum::Real
    maximum::Real
    minimum_inclusive::Bool
    maximum_inclusive::Bool
    recommended::Real

    function StateParameterSchema(
        name::Symbol,
        value_type::Type,
        doc::AbstractString,
        minimum::Real,
        maximum::Real,
        recommended::Real,
        ;
        minimum_inclusive::Bool=true,
        maximum_inclusive::Bool=true,
    )
        value_type !== Bool && value_type <: Real ||
            throw(ArgumentError("state parameter type must be a Real subtype"))
        any(value -> value isa Bool, (minimum, maximum, recommended)) &&
            throw(ArgumentError("state parameter bounds cannot be Bool"))
        all(isfinite, (minimum, maximum, recommended)) ||
            throw(ArgumentError("state parameter metadata must be finite"))
        all(value -> value isa value_type, (minimum, maximum, recommended)) ||
            throw(ArgumentError(
                "state parameter metadata does not match its value type",
            ))
        minimum <= maximum ||
            throw(ArgumentError("state parameter minimum exceeds maximum"))
        minimum == maximum &&
            !(minimum_inclusive && maximum_inclusive) &&
            throw(ArgumentError("state parameter interval is empty"))
        lower_recommendation_valid = minimum_inclusive ?
            minimum <= recommended : minimum < recommended
        upper_recommendation_valid = maximum_inclusive ?
            recommended <= maximum : recommended < maximum
        lower_recommendation_valid && upper_recommendation_valid ||
            throw(ArgumentError(
                "state parameter recommendation is outside its bounds",
            ))
        return new(
            name,
            value_type,
            String(doc),
            minimum,
            maximum,
            minimum_inclusive,
            maximum_inclusive,
            recommended,
        )
    end
end

function Base.in(value, parameter::StateParameterSchema)
    value isa Bool && return false
    value isa parameter.value_type || return false
    isfinite(value) || return false
    lower_valid = parameter.minimum_inclusive ?
        parameter.minimum <= value : parameter.minimum < value
    upper_valid = parameter.maximum_inclusive ?
        value <= parameter.maximum : value < parameter.maximum
    return lower_valid && upper_valid
end

"""
    StateFamilySchema

Stable constructor, parameter, and normalization metadata for one StatesZoo
family.
"""
struct StateFamilySchema
    family::Type
    doc::String
    parameters::Tuple{Vararg{StateParameterSchema}}
    normalization::StateNormalizationStyle

    function StateFamilySchema(
        family::Type,
        doc::AbstractString,
        parameters::Tuple{Vararg{StateParameterSchema}},
        normalization::StateNormalizationStyle,
    )
        family <: AbstractTwoQubitState ||
            throw(ArgumentError(
                "$family is not an AbstractTwoQubitState subtype",
            ))
        allunique(map(parameter -> parameter.name, parameters)) ||
            throw(ArgumentError(
                "state-family parameter names must be unique",
            ))
        return new(family, String(doc), parameters, normalization)
    end
end

const _BARRETT_KOK_PARAMETERS = (
    StateParameterSchema(
        :ηᴬ,
        Real,
        "Channel transmissivity from source A to the swapping station.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :ηᴮ,
        Real,
        "Channel transmissivity from source B to the swapping station.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :Pᵈ,
        Real,
        "Total excess detector noise in photons per qubit slot.",
        0,
        1,
        0,
        maximum_inclusive=false,
    ),
    StateParameterSchema(
        :ηᵈ,
        Real,
        "Photon-detector efficiency.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :𝒱,
        Real,
        "Real-valued mode overlap used by the standard parameter sweep.",
        0,
        1,
        1,
    ),
    StateParameterSchema(
        :m,
        Int,
        "Parity bit determined by the detector click pattern.",
        0,
        1,
        0,
    ),
)

const _DEPOLARIZED_PARAMETERS = (
    StateParameterSchema(
        :p,
        Real,
        "Depolarization parameter, related to fidelity by F=(3p+1)/4.",
        0,
        1,
        1,
    ),
)

const _GENQO_MULTIPLEXED_PARAMETERS = (
    StateParameterSchema(
        :ηᵇ,
        Real,
        "Bell-state-measurement transmissivity at the source.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :ηᵈ,
        Real,
        "Detector transmissivity.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :ηᵗ,
        Real,
        "Outcoupling transmissivity for the Bell-state modes.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :N,
        Real,
        "Mean photon number per mode.",
        0,
        10,
        0.1,
        minimum_inclusive=false,
    ),
)

const _GENQO_UNHERALDED_PARAMETERS = (
    StateParameterSchema(
        :ηᵈ,
        Real,
        "Detector transmissivity.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :ηᵗ,
        Real,
        "Outcoupling transmissivity for the Bell-state modes.",
        0,
        1,
        1,
        minimum_inclusive=false,
    ),
    StateParameterSchema(
        :N,
        Real,
        "Mean photon number per mode.",
        0,
        10,
        0.1,
        minimum_inclusive=false,
    ),
)

const _BARRETT_KOK_SCHEMA = StateFamilySchema(
    BarrettKokBellPair,
    "Normalized noisy Bell pair produced by a Barrett-Kok source.",
    _BARRETT_KOK_PARAMETERS,
    NormalizedState,
)

const _BARRETT_KOK_WEIGHTED_SCHEMA = StateFamilySchema(
    BarrettKokBellPairW,
    "Weighted Barrett-Kok Bell pair whose trace is its heralding probability.",
    _BARRETT_KOK_PARAMETERS,
    WeightedState,
)

const _DEPOLARIZED_SCHEMA = StateFamilySchema(
    DepolarizedBellPair,
    "Normalized depolarized Bell pair.",
    _DEPOLARIZED_PARAMETERS,
    NormalizedState,
)

const _GENQO_MULTIPLEXED_SCHEMA = StateFamilySchema(
    Genqo.GenqoMultiplexedCascadedBellPairW,
    "Weighted heralded multiplexed cascaded Bell-pair source.",
    _GENQO_MULTIPLEXED_PARAMETERS,
    WeightedState,
)

const _GENQO_UNHERALDED_SCHEMA = StateFamilySchema(
    Genqo.GenqoUnheraldedSPDCBellPairW,
    "Weighted unheralded SPDC Bell-pair source.",
    _GENQO_UNHERALDED_PARAMETERS,
    WeightedState,
)

"""
    state_family_schema(::Type{<:AbstractTwoQubitState})
    state_family_schema(::AbstractTwoQubitState)

Return stable, simulator-owned parameter and normalization metadata for a
supported state family. Packages defining custom families can add a method for
their type.
"""
function state_family_schema(::Type{T}) where {T<:AbstractTwoQubitState}
    throw(ArgumentError("no state-family schema is registered for $T"))
end
state_family_schema(state::AbstractTwoQubitState) =
    state_family_schema(typeof(state))

state_family_schema(::Type{BarrettKokBellPair}) = _BARRETT_KOK_SCHEMA
state_family_schema(::Type{BarrettKokBellPairW}) =
    _BARRETT_KOK_WEIGHTED_SCHEMA
state_family_schema(::Type{DepolarizedBellPair}) = _DEPOLARIZED_SCHEMA
state_family_schema(::Type{Genqo.GenqoMultiplexedCascadedBellPairW}) =
    _GENQO_MULTIPLEXED_SCHEMA
state_family_schema(::Type{Genqo.GenqoUnheraldedSPDCBellPairW}) =
    _GENQO_UNHERALDED_SCHEMA

"""
    state_family_schemas()

Return the explicit, deterministic catalog of built-in StatesZoo families.
"""
function state_family_schemas()
    return (
        _BARRETT_KOK_SCHEMA,
        _BARRETT_KOK_WEIGHTED_SCHEMA,
        _DEPOLARIZED_SCHEMA,
        _GENQO_MULTIPLEXED_SCHEMA,
        _GENQO_UNHERALDED_SCHEMA,
    )
end

"""
    state_normalization_style(::Type{<:AbstractTwoQubitState})
    state_normalization_style(::AbstractTwoQubitState)

Return whether a state family is normalized or trace-weighted.
"""
state_normalization_style(type::Type{<:AbstractTwoQubitState}) =
    state_family_schema(type).normalization
state_normalization_style(state::AbstractTwoQubitState) =
    state_normalization_style(typeof(state))

"""
    state_weight(state::AbstractTwoQubitState)

Return the finite, nonnegative absolute trace of `state`. For weighted
families, this is the success weight carried by the state.
"""
function state_weight(state::AbstractTwoQubitState)
    trace_value = express(tr(state))
    weight = abs(trace_value)
    weight isa Real && isfinite(weight) ||
        throw(DomainError(
            trace_value,
            "state trace must have a finite absolute value",
        ))
    return weight
end

"""
    normalized_state_and_weight(state::AbstractTwoQubitState)

Return `(state, weight)`, explicitly normalizing weighted families while
preserving their original absolute trace as `weight`. Already-normalized
families are returned unchanged. A zero-weight state cannot be normalized.
"""
function normalized_state_and_weight(state::AbstractTwoQubitState)
    normalization = state_normalization_style(state)
    weight = state_weight(state)
    weight > zero(weight) ||
        throw(DomainError(weight, "a zero-weight state cannot be normalized"))
    normalized_state =
        normalization === NormalizedState ? state : state / weight
    return (; state=normalized_state, weight)
end

"""
    state_parameter_values(parameter::StateParameterSchema, maximum_points::Integer)

Return an ordered grid of valid values for a state-family parameter. Integer
parameters produce integer-only grids, while continuous parameters respect
open and closed interval boundaries. At most `maximum_points` values are
returned.
"""
function state_parameter_values(
    parameter::StateParameterSchema,
    maximum_points::Integer,
)
    maximum_points isa Bool &&
        throw(ArgumentError("maximum_points must be a positive integer"))
    maximum_points > 0 ||
        throw(ArgumentError("maximum_points must be a positive integer"))

    if parameter.value_type <: Integer
        first_value = Int(parameter.minimum) + !parameter.minimum_inclusive
        last_value = Int(parameter.maximum) - !parameter.maximum_inclusive
        value_count = last_value - first_value + 1
        value_count > 0 ||
            throw(ArgumentError("integer parameter interval contains no values"))
        point_count = min(Int(maximum_points), value_count)
        point_count == 1 && return [parameter.recommended]
        values = round.(
            typeof(parameter.recommended),
            range(first_value, last_value; length=point_count),
        )
        return unique(values)
    end

    value_type = parameter.value_type
    grid_type = isconcretetype(value_type) && value_type <: AbstractFloat ?
        value_type : Float64
    minimum = convert(grid_type, parameter.minimum)
    maximum = convert(grid_type, parameter.maximum)
    margin = convert(grid_type, (maximum - minimum) * 0.0001)
    first_value = if parameter.minimum_inclusive
        minimum
    else
        candidate = minimum + margin
        candidate > minimum ? candidate : nextfloat(minimum)
    end
    last_value = if parameter.maximum_inclusive
        maximum
    else
        candidate = maximum - margin
        candidate < maximum ? candidate : prevfloat(maximum)
    end
    values = range(first_value, last_value; length=Int(maximum_points))
    all(value -> value in parameter, values) ||
        throw(ArgumentError("parameter interval cannot produce a valid grid"))
    return values
end
