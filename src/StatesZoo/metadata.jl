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

`minimum` and `maximum` are inclusive bounds. `recommended` is the default
point used by explorers and examples.
"""
struct StateParameterSchema
    name::Symbol
    value_type::Type
    doc::String
    minimum::Real
    maximum::Real
    recommended::Real

    function StateParameterSchema(
        name::Symbol,
        value_type::Type,
        doc::AbstractString,
        minimum::Real,
        maximum::Real,
        recommended::Real,
    )
        value_type !== Bool && value_type <: Real ||
            throw(ArgumentError("state parameter type must be a Real subtype"))
        any(value -> value isa Bool, (minimum, maximum, recommended)) &&
            throw(ArgumentError("state parameter bounds cannot be Bool"))
        all(isfinite, (minimum, maximum, recommended)) ||
            throw(ArgumentError("state parameter metadata must be finite"))
        minimum <= maximum ||
            throw(ArgumentError("state parameter minimum exceeds maximum"))
        minimum <= recommended <= maximum ||
            throw(ArgumentError(
                "state parameter recommendation is outside its bounds",
            ))
        recommended isa value_type ||
            throw(ArgumentError(
                "state parameter recommendation does not match its value type",
            ))
        return new(
            name,
            value_type,
            String(doc),
            minimum,
            maximum,
            recommended,
        )
    end
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
    ),
    StateParameterSchema(
        :ηᴮ,
        Real,
        "Channel transmissivity from source B to the swapping station.",
        0,
        1,
        1,
    ),
    StateParameterSchema(
        :Pᵈ,
        Real,
        "Total excess detector noise in photons per qubit slot.",
        0,
        1,
        0,
    ),
    StateParameterSchema(
        :ηᵈ,
        Real,
        "Photon-detector efficiency.",
        0,
        1,
        1,
    ),
    StateParameterSchema(
        :𝒱,
        Real,
        "Real-valued mode overlap used by the standard parameter sweep.",
        0,
        1,
        1,
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
    ),
    StateParameterSchema(
        :ηᵈ,
        Real,
        "Detector transmissivity.",
        0,
        1,
        1,
    ),
    StateParameterSchema(
        :ηᵗ,
        Real,
        "Outcoupling transmissivity for the Bell-state modes.",
        0,
        1,
        1,
    ),
    StateParameterSchema(
        :N,
        Real,
        "Mean photon number per mode.",
        0,
        10,
        0.1,
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
    ),
    StateParameterSchema(
        :ηᵗ,
        Real,
        "Outcoupling transmissivity for the Bell-state modes.",
        0,
        1,
        1,
    ),
    StateParameterSchema(
        :N,
        Real,
        "Mean photon number per mode.",
        0,
        10,
        0.1,
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
    stateparameters(::Type)

Return the ordered parameter names used by `stateexplorer`. This compatibility
API is derived from [`state_family_schema`](@ref).
"""
stateparameters(::Any) = ()
function stateparameters(type::Type{<:AbstractTwoQubitState})
    return map(parameter -> parameter.name, state_family_schema(type).parameters)
end

"""
    stateparametersrange(::Type)

Return legacy `(min, max, good)` parameter metadata derived from
[`state_family_schema`](@ref).
"""
stateparametersrange(::Any) = ()
function stateparametersrange(type::Type{<:AbstractTwoQubitState})
    parameters = state_family_schema(type).parameters
    names = map(parameter -> parameter.name, parameters)
    values = map(parameters) do parameter
        (
            min=parameter.minimum,
            max=parameter.maximum,
            good=parameter.recommended,
        )
    end
    return NamedTuple{names}(values)
end
