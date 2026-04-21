module QuantumSavoryInteractiveUtils

import QuantumSavory
using QuantumSavory.ProtocolZoo # to make them available in this namespace
import InteractiveUtils: subtypes
import REPL # in order to load Base.Docs.doc

function QuantumSavory.available_slot_types()
    types = subtypes(QuantumSavory.QuantumStateTrait)

    docs = [(type = T, doc = Base.Docs.doc(T)) for T in types] #TODO: edge case: no doc

    return docs
end

function QuantumSavory.available_background_types()
    types = subtypes(QuantumSavory.AbstractBackground)

    docs = [(type = T, doc = Base.Docs.doc(T)) for T in types]

    return docs
end

function QuantumSavory.ProtocolZoo.available_protocol_types()
    types = subtypes(QuantumSavory.ProtocolZoo.AbstractProtocol)
    types = filter(t->Base.ispublic(QuantumSavory.ProtocolZoo, name_of_UnionAll(t)), types)

    docs = [(type = T, doc = Base.Docs.doc(T), nodeargs = nodeargs(T)) for T in types]

    return docs
end

function nodeargs(::Type{T}) where {T<:QuantumSavory.ProtocolZoo.AbstractProtocol}
    metadata = QuantumSavory.constructor_metadata(T)
    (metadata[1].field == :sim && metadata[2].field == :net) || error(ArgumentError(lazy"Protocol $(T) is structured incorrectly -- the `sim` and `net` fields are not in the expected location."))
    length(filter(metadata[3:end]) do m
        m.field ∈ (:node, :nodeA, :nodeB)
    end)
end

types_of_UnionAll(t::DataType) = t.types
types_of_UnionAll(t::UnionAll) = types_of_UnionAll(t.body)
name_of_UnionAll(t::DataType) = t.name.name
name_of_UnionAll(t::UnionAll) = name_of_UnionAll(t.body)

# Taken from DocStringExtensions.format(::TupleFields)
function QuantumSavory.constructor_metadata(::Type{T}) where {T}
    fields = fieldnames(T)
    types = types_of_UnionAll(T)
    typedoc = Base.Docs.doc(T)
    binding = typedoc.meta[:binding]
    object = Docs.resolve(binding)
    fieldsdata = typedoc.meta[:results][1].data[:fields]

    # the metadata includes only documented fields
    metadata = [(;field, type, doc = fieldsdata[field]) for (field, type) in zip(fields, types) if haskey(fieldsdata, field) && !startswith(string(field), "_")]

    return metadata
end

end
