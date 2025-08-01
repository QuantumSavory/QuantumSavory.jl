module QuantumSavoryInteractiveUtils

using QuantumSavory
import InteractiveUtils: subtypes

function available_slot_types()
    types = subtypes(QuantumStateTrait)

    docs = [(type = T, doc = Base.Docs.doc(T)) for T in types] #TODO: edge case: no doc

    return docs
end

function available_background_types()
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

end
