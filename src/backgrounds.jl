"""A background describing the T₁ decay of a two-level system."""
struct T1Decay <: AbstractBackground
    t1
end

"""A background describing the T₂ dephasing of a two-level system."""
struct T2Dephasing <: AbstractBackground
    t2
end

"""A depolarization background.

The `τ` parameter specifies the average time between depolarization events (assuming a Poisson point process).
I.e. after time `t` the probability for an depolarization event is `1-exp(-t/τ)`.
"""
struct Depolarization <: AbstractBackground
    τ
end

"""A Pauli noise background."""
struct PauliNoise <: AbstractBackground
    τˣ
    τʸ
    τᶻ
end

"""A depolarization background."""
struct AmplitudeDamping <: AbstractBackground
    τ
end

# TODO
# T1T2Noise
# T1TwirledDecay
# T1T2TwirledNoise

using InteractiveUtils 
import PrettyTables: pretty_table

function available_background_types()
    types = subtypes(AbstractBackground)

    docs = [(type = T, doc = Base.Docs.doc(T)) for T in types] #TODO: edge case: no doc

    pretty_table(docs; crop = :none, header = ["Type", "Docstring"])

    return docs
end


function constructor_metadata(::Type{T}) where {T<:AbstractBackground}
    fields = fieldnames(T)
    types = T.types

    metadata = [(arg = fields[i], type = types[i]) for i in eachindex(fields)]

    pretty_table(metadata; crop = :none)

    return metadata
end