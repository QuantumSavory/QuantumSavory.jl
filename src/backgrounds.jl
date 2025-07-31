"""A background describing the T₁ decay of a two-level system."""
struct T1Decay <: AbstractBackground
    "The T₁ time of the two-level system."
    t1::Float64 # TODO consider parameterizing the type
end

"""A background describing the T₂ dephasing of a two-level system."""
struct T2Dephasing <: AbstractBackground
    "The T₂ time of the two-level system."
    t2::Float64 # TODO consider parameterizing the type
end

"""A depolarization background.

The `τ` parameter specifies the average time between depolarization events (assuming a Poisson point process).
I.e. after time `t` the probability for an depolarization event is `1-exp(-t/τ)`.
"""
struct Depolarization <: AbstractBackground
    "The average time between depolarization events (assuming a Poisson point process)."
    τ::Float64 # TODO consider parameterizing the type
end

"""A Pauli noise background."""
struct PauliNoise <: AbstractBackground
    "The average time between X noise events (assuming a Poisson point process)."
    τˣ::Float64 # TODO consider parameterizing the type
    "The average time between Y noise events (assuming a Poisson point process)."
    τʸ::Float64
    "The average time between Z noise events (assuming a Poisson point process)."
    τᶻ::Float64
end

"""A depolarization background."""
struct AmplitudeDamping <: AbstractBackground
    "The characteristic time of the amplitude damping process."
    τ::Float64 # TODO consider parameterizing the type
end

# TODO
# T1T2Noise
# T1TwirledDecay
# T1T2TwirledNoise


function available_background_types() # TODO move this to an extension that loads when the InteractiveUtils is loaded
    types = subtypes(AbstractBackground)

    docs = [(type = T, doc = Base.Docs.doc(T)) for T in types]

    return docs
end

# Taken from DocStringExtensions.format(::TupeFields)
function constructor_metadata(::Type{T}) where {T<:AbstractBackground}
    fields = fieldnames(T)
    types = T.types
    typedoc = Base.Docs.doc(T)
    binding = typedoc.meta[:binding]
    object = Docs.resolve(binding)
    fieldsdata = typedoc.meta[:results][1].data[:fields]

    metadata = [(;field, type, doc = fieldsdata[field]) for (field, type) in zip(fields, types)]

    return metadata
end
