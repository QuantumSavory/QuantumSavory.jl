"""
    ConstructorFieldSchema

Stable metadata for one user-supplied constructor field.

`declared_type` is the Julia type accepted by the constructor. `minimum` and
`maximum` are inclusive numeric constraints when the simulator declares them;
`nothing` means that the simulator does not declare that bound.
"""
struct ConstructorFieldSchema
    name::Symbol
    declared_type::Type
    doc::String
    minimum::Union{Nothing,Real}
    maximum::Union{Nothing,Real}

    function ConstructorFieldSchema(
        name::Symbol,
        declared_type::Type,
        doc::AbstractString,
        minimum::Union{Nothing,Real},
        maximum::Union{Nothing,Real},
    )
        minimum isa Bool &&
            throw(ArgumentError("constructor-field minimum cannot be Bool"))
        maximum isa Bool &&
            throw(ArgumentError("constructor-field maximum cannot be Bool"))
        minimum !== nothing && !isfinite(minimum) &&
            throw(ArgumentError("constructor-field minimum must be finite"))
        maximum !== nothing && !isfinite(maximum) &&
            throw(ArgumentError("constructor-field maximum must be finite"))
        minimum !== nothing && maximum !== nothing && minimum > maximum &&
            throw(ArgumentError("constructor-field minimum exceeds maximum"))
        return new(name, declared_type, String(doc), minimum, maximum)
    end
end

function ConstructorFieldSchema(
    name::Symbol,
    declared_type::Type,
    doc::AbstractString;
    minimum::Union{Nothing,Real}=nothing,
    maximum::Union{Nothing,Real}=nothing,
)
    return ConstructorFieldSchema(name, declared_type, doc, minimum, maximum)
end

"""
    ConstructorSchema

Stable metadata for one constructor exposed by QuantumSavory.

The fields are ordered exactly as they should be presented to a caller. A
schema is intentionally independent of Julia's method table, loaded packages,
and documentation internals.
"""
struct ConstructorSchema
    constructor::Type
    doc::String
    fields::Tuple{Vararg{ConstructorFieldSchema}}

    function ConstructorSchema(
        constructor::Type,
        doc::AbstractString,
        fields::Tuple{Vararg{ConstructorFieldSchema}}=(),
    )
        names = map(field -> field.name, fields)
        allunique(names) ||
            throw(ArgumentError("constructor schema has duplicate field names"))
        return new(constructor, String(doc), fields)
    end
end

"""
    constructor_schema(::Type)

Return stable, simulator-owned constructor metadata for a supported component
type. Packages defining custom components can add a method for their type.
"""
function constructor_schema(::Type{T}) where {T}
    throw(ArgumentError("no constructor schema is registered for $T"))
end

"""
    constructor_constraints(::Type, ::Val{field})

Return the inclusive `(minimum, maximum)` bounds declared for `field`.
"""
function constructor_constraints(type::Type, ::Val{name}) where {name}
    schema = constructor_schema(type)
    index = findfirst(field -> field.name === name, schema.fields)
    index === nothing &&
        throw(ArgumentError("constructor $(schema.constructor) has no field $name"))
    field = schema.fields[index]
    return (; minimum=field.minimum, maximum=field.maximum)
end

function _constructor_field(
    constructor::Type,
    name::Symbol,
    doc::AbstractString;
    minimum::Union{Nothing,Real}=nothing,
    maximum::Union{Nothing,Real}=nothing,
)
    return ConstructorFieldSchema(
        name,
        fieldtype(constructor, name),
        doc;
        minimum,
        maximum,
    )
end

const _QUBIT_SCHEMA = ConstructorSchema(
    Qubit,
    "A register-slot trait representing a two-level quantum system.",
)
const _QUMODE_SCHEMA = ConstructorSchema(
    Qumode,
    "A register-slot trait representing a bosonic mode.",
)

const _CLIFFORD_REPR_SCHEMA = ConstructorSchema(
    CliffordRepr,
    "A stabilizer-tableau representation for Clifford-compatible workloads.",
)
const _QUANTUM_OPTICS_REPR_SCHEMA = ConstructorSchema(
    QuantumOpticsRepr,
    "A dense or sparse state/operator representation provided by QuantumOptics.",
    (
        _constructor_field(
            QuantumOpticsRepr,
            :cutoff,
            "Fock-space cutoff dimension used for bosonic modes.";
            minimum=1,
        ),
    ),
)
const _QUANTUM_MC_REPR_SCHEMA = ConstructorSchema(
    QuantumMCRepr,
    "A Monte Carlo trajectory representation for pure-state simulations.",
)

const _T1_DECAY_SCHEMA = ConstructorSchema(
    T1Decay,
    "T₁ decay of a two-level system.",
    (
        _constructor_field(
            T1Decay,
            :t1,
            "T₁ relaxation time of the two-level system.",
        ),
    ),
)
const _T2_DEPHASING_SCHEMA = ConstructorSchema(
    T2Dephasing,
    "T₂ dephasing of a two-level system.",
    (
        _constructor_field(
            T2Dephasing,
            :t2,
            "T₂ dephasing time of the two-level system.",
        ),
    ),
)
const _T1_T2_NOISE_SCHEMA = ConstructorSchema(
    T1T2Noise,
    "Combined T₁ decay and T₂ dephasing.",
    (
        _constructor_field(
            T1T2Noise,
            :t1,
            "T₁ relaxation time of the two-level system.",
        ),
        _constructor_field(
            T1T2Noise,
            :t2,
            "T₂ dephasing time of the two-level system.",
        ),
    ),
)
const _DEPOLARIZATION_SCHEMA = ConstructorSchema(
    Depolarization,
    "Poisson-distributed depolarization events.",
    (
        _constructor_field(
            Depolarization,
            :τ,
            "Average time between depolarization events.",
        ),
    ),
)
const _PAULI_NOISE_SCHEMA = ConstructorSchema(
    PauliNoise,
    "Independent Poisson-distributed Pauli noise events.",
    (
        _constructor_field(PauliNoise, :τˣ, "Average time between X events."),
        _constructor_field(PauliNoise, :τʸ, "Average time between Y events."),
        _constructor_field(PauliNoise, :τᶻ, "Average time between Z events."),
    ),
)
const _AMPLITUDE_DAMPING_SCHEMA = ConstructorSchema(
    AmplitudeDamping,
    "Amplitude damping with a characteristic decay time.",
    (
        _constructor_field(
            AmplitudeDamping,
            :τ,
            "Characteristic time of the amplitude-damping process.",
        ),
    ),
)

constructor_schema(::Type{Qubit}) = _QUBIT_SCHEMA
constructor_schema(::Type{Qumode}) = _QUMODE_SCHEMA
constructor_schema(::Type{CliffordRepr}) = _CLIFFORD_REPR_SCHEMA
constructor_schema(::Type{QuantumOpticsRepr}) = _QUANTUM_OPTICS_REPR_SCHEMA
constructor_schema(::Type{QuantumMCRepr}) = _QUANTUM_MC_REPR_SCHEMA
constructor_schema(::Type{T1Decay}) = _T1_DECAY_SCHEMA
constructor_schema(::Type{T2Dephasing}) = _T2_DEPHASING_SCHEMA
constructor_schema(::Type{T1T2Noise}) = _T1_T2_NOISE_SCHEMA
constructor_schema(::Type{Depolarization}) = _DEPOLARIZATION_SCHEMA
constructor_schema(::Type{PauliNoise}) = _PAULI_NOISE_SCHEMA
constructor_schema(::Type{AmplitudeDamping}) = _AMPLITUDE_DAMPING_SCHEMA

"""
    slot_schemas()

Return the explicit, deterministic catalog of built-in register-slot traits.
"""
slot_schemas() = (_QUBIT_SCHEMA, _QUMODE_SCHEMA)

"""
    representation_schemas()

Return the explicit, deterministic catalog of built-in numerical
representations supported by register constructors.
"""
function representation_schemas()
    return (
        _CLIFFORD_REPR_SCHEMA,
        _QUANTUM_OPTICS_REPR_SCHEMA,
        _QUANTUM_MC_REPR_SCHEMA,
    )
end

"""
    background_schemas()

Return the explicit, deterministic catalog of public background-noise
constructors. Internal backend helpers are deliberately excluded.
"""
function background_schemas()
    return (
        _T1_DECAY_SCHEMA,
        _T2_DEPHASING_SCHEMA,
        _T1_T2_NOISE_SCHEMA,
        _DEPOLARIZATION_SCHEMA,
        _PAULI_NOISE_SCHEMA,
        _AMPLITUDE_DAMPING_SCHEMA,
    )
end
