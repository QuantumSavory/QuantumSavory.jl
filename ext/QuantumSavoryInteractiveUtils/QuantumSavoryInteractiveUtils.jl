module QuantumSavoryInteractiveUtils

import QuantumSavory
const ProtocolZoo = QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo # make protocol bindings available for doc resolution
import InteractiveUtils: subtypes
import REPL # load the Base.Docs.doc methods

_qualified_type_name(T) = string(parentmodule(T), ".", nameof(T))

function _available_types(root)
    available = Any[]
    seen = IdSet{Any}()

    function visit(T)
        for subtype in subtypes(T)
            subtype in seen && continue
            push!(seen, subtype)
            if isabstracttype(subtype)
                visit(subtype)
            elseif Base.ispublic(parentmodule(subtype), nameof(subtype))
                push!(available, subtype)
            end
        end
    end

    visit(root)
    sort!(available; by=_qualified_type_name)
    return available
end

function QuantumSavory.available_slot_types()
    return [
        (type=T, doc=Base.Docs.doc(T))
        for T in _available_types(QuantumSavory.QuantumStateTrait)
    ]
end

function QuantumSavory.available_background_types()
    return [
        (type=T, doc=Base.Docs.doc(T))
        for T in _available_types(QuantumSavory.AbstractBackground)
    ]
end

types_of_unionall(T::DataType) = T.types
types_of_unionall(T::UnionAll) = types_of_unionall(T.body)

function documented_fields(T)
    typedoc = Base.Docs.doc(T)
    docs = Dict{Symbol,Any}()
    for result in get(typedoc.meta, :results, ())
        for (field, doc) in get(result.data, :fields, ())
            haskey(docs, field) || (docs[field] = doc)
        end
    end
    return docs
end

# Adapted from DocStringExtensions.format(::TupleFields).
function QuantumSavory.constructor_metadata(::Type{T}) where {T}
    docs = documented_fields(T)
    return [
        (field=field, type=type, doc=docs[field])
        for (field, type) in zip(fieldnames(T), types_of_unionall(T))
        if haskey(docs, field) && !startswith(String(field), "_")
    ]
end

QuantumSavory.constructor_metadata(
    ::Type{QuantumSavory.StatesZoo.BarrettKokBellPairW},
) = QuantumSavory.constructor_metadata(QuantumSavory.StatesZoo.BarrettKokBellPair)

function metadata_error(T, message)
    throw(ArgumentError(
        "invalid protocol catalog metadata for $(_qualified_type_name(T)): $(message)",
    ))
end

function validated_protocol_metadata(T)
    metadata = ProtocolZoo.protocol_catalog_metadata(T)
    expected_keys = (:attachment, :attachment_fields, :required_fields)
    metadata isa NamedTuple || metadata_error(
        T,
        "metadata must be a named tuple with fields $(expected_keys); got $(typeof(metadata))",
    )
    keys(metadata) == expected_keys || metadata_error(
        T,
        "metadata fields must be $(expected_keys); got $(keys(metadata))",
    )

    attachment = metadata.attachment
    attachment in (:network, :node, :edge) || metadata_error(
        T,
        "attachment must be :network, :node, or :edge; got $(repr(attachment))",
    )

    attachment_fields = metadata.attachment_fields
    attachment_fields isa NamedTuple || metadata_error(
        T,
        "attachment_fields must be a named tuple; got $(typeof(attachment_fields))",
    )
    expected_roles = if attachment === :network
        ()
    elseif attachment === :node
        (:node,)
    else
        (:node_a, :node_b)
    end
    keys(attachment_fields) == expected_roles || metadata_error(
        T,
        "attachment_fields for $(repr(attachment)) must have roles $(expected_roles); " *
        "got $(keys(attachment_fields))",
    )

    mapped_fields = Tuple(values(attachment_fields))
    all(field -> field isa Symbol, mapped_fields) || metadata_error(
        T,
        "attachment_fields values must be constructor-field symbols; got $(repr(mapped_fields))",
    )
    length(unique(mapped_fields)) == length(mapped_fields) || metadata_error(
        T,
        "attachment_fields must map roles to unique constructor fields; got $(repr(mapped_fields))",
    )

    constructor_fields = QuantumSavory.constructor_metadata(T)
    documented_names = Tuple(field.field for field in constructor_fields)
    nonprivate_fields = filter(
        field -> !startswith(String(field), "_"),
        fieldnames(T),
    )
    for injected_field in (:sim, :net)
        injected_field in nonprivate_fields || metadata_error(
            T,
            "protocols in the catalog must define the injected field $(repr(injected_field))",
        )
    end
    undocumented_fields = filter(field -> field ∉ documented_names, nonprivate_fields)
    isempty(undocumented_fields) || metadata_error(
        T,
        "every non-private constructor field must be documented; missing " *
        "$(repr(Tuple(undocumented_fields)))",
    )

    for (role, field) in pairs(attachment_fields)
        field in documented_names || metadata_error(
            T,
            "attachment role $(repr(role)) maps to $(repr(field)), which is not a " *
            "documented constructor field",
        )
        field ∉ (:sim, :net) || metadata_error(
            T,
            "attachment role $(repr(role)) cannot map to injected field $(repr(field))",
        )
    end

    required_fields = metadata.required_fields
    required_fields isa Tuple || metadata_error(
        T,
        "required_fields must be a tuple of configurable field symbols; got " *
        "$(typeof(required_fields))",
    )
    all(field -> field isa Symbol, required_fields) || metadata_error(
        T,
        "required_fields must contain only field symbols; got $(repr(required_fields))",
    )
    length(unique(required_fields)) == length(required_fields) || metadata_error(
        T,
        "required_fields must be unique; got $(repr(required_fields))",
    )

    configurable_fields = filter(
        field -> field ∉ (:sim, :net) && field ∉ mapped_fields,
        documented_names,
    )
    for field in required_fields
        field in configurable_fields || metadata_error(
            T,
            "required field $(repr(field)) is not a configurable constructor field",
        )
    end

    return (; attachment, attachment_fields, required_fields, constructor_fields)
end

function ProtocolZoo.available_protocol_types()
    types = filter(_available_types(ProtocolZoo.AbstractProtocol)) do T
        applicable(ProtocolZoo.protocol_catalog_metadata, T)
    end

    return map(types) do T
        metadata = validated_protocol_metadata(T)
        mapped_fields = Tuple(values(metadata.attachment_fields))
        parameters = [
            (
                field=field.field,
                type=field.type,
                doc=field.doc,
                required=field.field in metadata.required_fields,
            )
            for field in metadata.constructor_fields
            if field.field ∉ (:sim, :net) && field.field ∉ mapped_fields
        ]
        return (
            type=T,
            doc=Base.Docs.doc(T),
            nodeargs=length(mapped_fields),
            attachment=metadata.attachment,
            attachment_fields=metadata.attachment_fields,
            parameters=parameters,
            permits_virtual_edge=ProtocolZoo.permits_virtual_edge(T),
        )
    end
end

end
