"""
    TagFieldSchema

Stable metadata for one ordered field of a named tag head.
"""
struct TagFieldSchema
    name::Symbol
    declared_type::Type
    doc::String

    function TagFieldSchema(
        name::Symbol,
        declared_type::Type,
        doc::AbstractString,
    )
        return new(name, declared_type, String(doc))
    end
end

"""
    TagHeadSchema

Stable metadata for a concrete [`AbstractTag`](@ref) head and all of its
ordered fields.
"""
struct TagHeadSchema
    head::DataType
    doc::String
    fields::Tuple{Vararg{TagFieldSchema}}

    function TagHeadSchema(
        head::DataType,
        doc::AbstractString,
        fields::Tuple{Vararg{TagFieldSchema}},
    )
        isconcretetype(head) ||
            throw(ArgumentError("tag head must be concrete"))
        head <: AbstractTag ||
            throw(ArgumentError("$head is not an AbstractTag subtype"))
        names = map(field -> field.name, fields)
        names == fieldnames(head) ||
            throw(ArgumentError(
                "tag schema fields must exactly match the layout of $head",
            ))
        all(
            field -> field.declared_type === fieldtype(head, field.name),
            fields,
        ) || throw(ArgumentError(
            "tag schema field types must match the layout of $head",
        ))
        return new(head, String(doc), fields)
    end
end

"""
    TagSignatureSchema

One supported generic [`Tag`](@ref) constructor shape. `head_type` is either
`Symbol` or `DataType`; `field_types` excludes that leading head.
"""
struct TagSignatureSchema
    head_type::DataType
    field_types::Tuple{Vararg{Type}}

    function TagSignatureSchema(
        head_type::DataType,
        field_types::Tuple{Vararg{Type}},
    )
        head_type in (Symbol, DataType) ||
            throw(ArgumentError("tag head type must be Symbol or DataType"))
        return new(head_type, field_types)
    end
end

"""
    TagParts

An immutable, representation-independent view of a [`Tag`](@ref). `head` is
the first constructor value and `fields` contains the remaining values.
"""
struct TagParts{H,F<:Tuple}
    head::H
    fields::F
end

"""
    tag_parts(tag::Tag)

Return the logical head and field tuple of `tag` without exposing its internal
sum-type variant.
"""
function tag_parts(tag::Tag)
    values = Tuple(tag)
    return TagParts(first(values), Base.tail(values))
end

function _tag_head_schema(
    head::DataType,
    doc::AbstractString,
    fields::Tuple,
)
    field_schemas = map(fields) do field
        name, field_doc = field
        TagFieldSchema(name, fieldtype(head, name), field_doc)
    end
    return TagHeadSchema(head, doc, field_schemas)
end

const _ENTANGLEMENT_COUNTERPART_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.EntanglementCounterpart,
    "Current entanglement with a remote register slot.",
    (
        (:remote_node, "Remote node identifier."),
        (:remote_slot, "Remote register-slot index."),
        (:pair_id, "Entangled-pair identifier."),
    ),
)

const _ENTANGLEMENT_HISTORY_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.EntanglementHistory,
    "Previous and current counterpart metadata retained after a swap.",
    (
        (:remote_node, "Previous remote node identifier."),
        (:remote_slot, "Previous remote register-slot index."),
        (:swap_remote_node, "Remote node identifier after the swap."),
        (:swap_remote_slot, "Remote register-slot index after the swap."),
        (:swapped_local, "Local slot used for the swap."),
        (:local_chunk_id, "Pair-id chunk for the previous counterpart."),
        (:swapped_chunk_id, "Pair-id chunk for the swapped counterpart."),
    ),
)

const _ENTANGLEMENT_UPDATE_X_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.EntanglementUpdateX,
    "Remote counterpart update carrying an X-basis swap result.",
    (
        (:target_pair_id, "Pair identifier currently known by the receiver."),
        (:other_pair_id, "Pair-id chunk to combine into the target pair."),
        (:past_local_node, "Remote node identifier before the swap."),
        (:past_local_slot, "Remote slot index before the swap."),
        (:past_remote_slot, "Receiver slot index before the swap."),
        (:new_remote_node, "Remote node identifier after the swap."),
        (:new_remote_slot, "Remote slot index after the swap."),
        (:correction, "Pauli-frame correction bit."),
    ),
)

const _ENTANGLEMENT_UPDATE_Z_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.EntanglementUpdateZ,
    "Remote counterpart update carrying a Z-basis swap result.",
    (
        (:target_pair_id, "Pair identifier currently known by the receiver."),
        (:other_pair_id, "Pair-id chunk to combine into the target pair."),
        (:past_local_node, "Remote node identifier before the swap."),
        (:past_local_slot, "Remote slot index before the swap."),
        (:past_remote_slot, "Receiver slot index before the swap."),
        (:new_remote_node, "Remote node identifier after the swap."),
        (:new_remote_slot, "Remote slot index after the swap."),
        (:correction, "Pauli-frame correction bit."),
    ),
)

const _ENTANGLEMENT_DELETE_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.EntanglementDelete,
    "Notification that one side of an entangled pair was deleted.",
    (
        (:target_pair_id, "Pair identifier targeted by the deletion."),
        (:send_node, "Node that sent the deletion notice."),
        (:send_slot, "Sender slot that was deleted."),
        (:rec_node, "Node receiving the deletion notice."),
        (:rec_slot, "Receiver slot paired with the deleted slot."),
    ),
)

const _SWITCH_REQUEST_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.SwitchRequest,
    "Request for a switch to connect two client nodes.",
    (
        (:requester, "Node making the request."),
        (:remote_node, "Requested remote counterpart node."),
    ),
)

const _FLOW_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.Flow,
    "QTCP request for a flow of entangled pairs.",
    (
        (:src, "Flow source node."),
        (:dst, "Flow destination node."),
        (:npairs, "Number of requested pairs."),
        (:uuid, "Flow identifier."),
    ),
)

const _QTCP_PAIR_BEGIN_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.QTCPPairBegin,
    "QTCP endpoint metadata for the beginning of a delivered pair.",
    (
        (:flow_uuid, "Flow identifier."),
        (:flow_src, "Flow source node."),
        (:flow_dst, "Flow destination node."),
        (:seq_num, "Pair sequence number."),
        (:memory_slot, "Local memory-slot index."),
        (:start_time, "Original datagram start time."),
    ),
)

const _QTCP_PAIR_END_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.QTCPPairEnd,
    "QTCP endpoint metadata for the end of a delivered pair.",
    (
        (:flow_uuid, "Flow identifier."),
        (:flow_src, "Flow source node."),
        (:flow_dst, "Flow destination node."),
        (:seq_num, "Pair sequence number."),
        (:memory_slot, "Local memory-slot index."),
        (:start_time, "Original datagram start time."),
    ),
)

const _QDATAGRAM_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.QDatagram,
    "QTCP datagram requesting one end-to-end entangled pair.",
    (
        (:flow_uuid, "Flow identifier."),
        (:flow_src, "Flow source node."),
        (:flow_dst, "Flow destination node."),
        (:correction, "Accumulated Pauli-frame correction."),
        (:seq_num, "Pair sequence number."),
        (:start_time, "Original datagram start time."),
    ),
)

const _QDATAGRAM_SUCCESS_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.QTCP.QDatagramSuccess,
    "QTCP acknowledgement for a delivered datagram.",
    (
        (:flow_uuid, "Flow identifier."),
        (:seq_num, "Pair sequence number."),
        (:start_time, "Original datagram start time."),
    ),
)

const _LINK_LEVEL_REQUEST_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.LinkLevelRequest,
    "QTCP request for link-level entanglement.",
    (
        (:flow_uuid, "Flow identifier."),
        (:seq_num, "Pair sequence number."),
        (:remote_node, "Requested remote link endpoint."),
    ),
)

const _LINK_LEVEL_REPLY_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.LinkLevelReply,
    "QTCP reply identifying newly generated link-level entanglement.",
    (
        (:flow_uuid, "Flow identifier."),
        (:seq_num, "Pair sequence number."),
        (:memory_slot, "Memory slot containing the local qubit."),
    ),
)

const _LINK_LEVEL_REPLY_AT_SOURCE_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.LinkLevelReplyAtSource,
    "QTCP link-level reply retained at a flow source.",
    (
        (:flow_uuid, "Flow identifier."),
        (:seq_num, "Pair sequence number."),
        (:memory_slot, "Memory slot containing the local qubit."),
    ),
)

const _LINK_LEVEL_REPLY_AT_HOP_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.LinkLevelReplyAtHop,
    "QTCP link-level reply retained at an intermediate hop.",
    (
        (:flow_uuid, "Flow identifier."),
        (:seq_num, "Pair sequence number."),
        (:memory_slot, "Memory slot containing the local qubit."),
    ),
)

const _GRAPH_STATE_STORAGE_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.MBQCEntanglementDistillation.GraphStateStorage,
    "Stored graph-state vertex metadata.",
    (
        (:uuid, "Graph-state identifier."),
        (:vertex, "Logical graph vertex."),
    ),
)

const _PURIFIER_MEASUREMENT_RESULTS_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.MBQCEntanglementDistillation.PurifierBellMeasurementResults,
    "Bit-packed Bell-measurement results used by MBQC purification.",
    (
        (:node, "Node that performed the measurements."),
        (:measurements_XX, "Bit-packed XX measurement results."),
        (:measurements_ZZ, "Bit-packed ZZ measurement results."),
    ),
)

const _PURIFIED_COUNTERPART_TAG_SCHEMA = _tag_head_schema(
    ProtocolZoo.MBQCEntanglementDistillation.PurifiedEntanglementCounterpart,
    "Purified entanglement with a remote register slot.",
    (
        (:remote_node, "Remote node identifier."),
        (:remote_slot, "Remote register-slot index."),
    ),
)

"""
    tag_head_schema(::Type{<:AbstractTag})

Return stable, simulator-owned metadata for a supported named tag head.
Packages defining custom tag heads can add a method for their type.
"""
function tag_head_schema(::Type{T}) where {T<:AbstractTag}
    throw(ArgumentError("no tag-head schema is registered for $T"))
end

tag_head_schema(::Type{ProtocolZoo.EntanglementCounterpart}) =
    _ENTANGLEMENT_COUNTERPART_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.EntanglementHistory}) =
    _ENTANGLEMENT_HISTORY_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.EntanglementUpdateX}) =
    _ENTANGLEMENT_UPDATE_X_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.EntanglementUpdateZ}) =
    _ENTANGLEMENT_UPDATE_Z_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.EntanglementDelete}) =
    _ENTANGLEMENT_DELETE_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.SwitchRequest}) =
    _SWITCH_REQUEST_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.Flow}) = _FLOW_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.QTCPPairBegin}) =
    _QTCP_PAIR_BEGIN_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.QTCPPairEnd}) = _QTCP_PAIR_END_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.QDatagram}) = _QDATAGRAM_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.QTCP.QDatagramSuccess}) =
    _QDATAGRAM_SUCCESS_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.LinkLevelRequest}) =
    _LINK_LEVEL_REQUEST_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.LinkLevelReply}) =
    _LINK_LEVEL_REPLY_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.LinkLevelReplyAtSource}) =
    _LINK_LEVEL_REPLY_AT_SOURCE_TAG_SCHEMA
tag_head_schema(::Type{ProtocolZoo.LinkLevelReplyAtHop}) =
    _LINK_LEVEL_REPLY_AT_HOP_TAG_SCHEMA
tag_head_schema(
    ::Type{ProtocolZoo.MBQCEntanglementDistillation.GraphStateStorage},
) = _GRAPH_STATE_STORAGE_TAG_SCHEMA
tag_head_schema(
    ::Type{
        ProtocolZoo.MBQCEntanglementDistillation.PurifierBellMeasurementResults
    },
) = _PURIFIER_MEASUREMENT_RESULTS_TAG_SCHEMA
tag_head_schema(
    ::Type{
        ProtocolZoo.MBQCEntanglementDistillation.PurifiedEntanglementCounterpart
    },
) = _PURIFIED_COUNTERPART_TAG_SCHEMA

"""
    tag_head_schemas()

Return the explicit, deterministic catalog of built-in named tag heads.
"""
function tag_head_schemas()
    return (
        _ENTANGLEMENT_COUNTERPART_TAG_SCHEMA,
        _ENTANGLEMENT_HISTORY_TAG_SCHEMA,
        _ENTANGLEMENT_UPDATE_X_TAG_SCHEMA,
        _ENTANGLEMENT_UPDATE_Z_TAG_SCHEMA,
        _ENTANGLEMENT_DELETE_TAG_SCHEMA,
        _SWITCH_REQUEST_TAG_SCHEMA,
        _FLOW_TAG_SCHEMA,
        _QTCP_PAIR_BEGIN_TAG_SCHEMA,
        _QTCP_PAIR_END_TAG_SCHEMA,
        _QDATAGRAM_TAG_SCHEMA,
        _QDATAGRAM_SUCCESS_TAG_SCHEMA,
        _LINK_LEVEL_REQUEST_TAG_SCHEMA,
        _LINK_LEVEL_REPLY_TAG_SCHEMA,
        _LINK_LEVEL_REPLY_AT_SOURCE_TAG_SCHEMA,
        _LINK_LEVEL_REPLY_AT_HOP_TAG_SCHEMA,
        _GRAPH_STATE_STORAGE_TAG_SCHEMA,
        _PURIFIER_MEASUREMENT_RESULTS_TAG_SCHEMA,
        _PURIFIED_COUNTERPART_TAG_SCHEMA,
    )
end

const _GENERAL_TAG_SIGNATURES = (
    TagSignatureSchema(Symbol, ()),
    TagSignatureSchema(Symbol, (Int,)),
    TagSignatureSchema(Symbol, (Int, Int)),
    TagSignatureSchema(Symbol, (Int, Int, Int)),
    TagSignatureSchema(Symbol, (Int, Int, Int, Int)),
    TagSignatureSchema(Symbol, (Int, Int, Int, Int, Int)),
    TagSignatureSchema(Symbol, (Int, Int, Int, Int, Int, Int)),
    TagSignatureSchema(Symbol, (Float64,)),
    TagSignatureSchema(Symbol, (Float64, Float64)),
    TagSignatureSchema(DataType, ()),
    TagSignatureSchema(DataType, (Int,)),
    TagSignatureSchema(DataType, (Int, Int)),
    TagSignatureSchema(DataType, (Int, Int, Int)),
    TagSignatureSchema(DataType, (Int, Int, Int, Int)),
    TagSignatureSchema(DataType, (Int, Int, Int, Int, Int)),
    TagSignatureSchema(DataType, (Int, Int, Int, Int, Int, Int)),
    TagSignatureSchema(DataType, (Int, Int, Int, Int, Int, Int, Int)),
    TagSignatureSchema(DataType, (Int, Int, Int, Int, Int, Int, Int, Int)),
    TagSignatureSchema(DataType, (Int, Float64)),
    TagSignatureSchema(DataType, (Int, Int, Float64)),
    TagSignatureSchema(DataType, (Int, Int, Int, Float64)),
    TagSignatureSchema(DataType, (Int, Int, Int, Int, Float64)),
    TagSignatureSchema(DataType, (Int, Int, Int, Int, Int, Float64)),
    TagSignatureSchema(DataType, (Symbol,)),
    TagSignatureSchema(DataType, (Symbol, Int)),
    TagSignatureSchema(DataType, (Symbol, Int, Int)),
)

"""
    general_tag_signatures()

Return the explicit, deterministic catalog of supported generic `Tag`
constructor shapes. Internal forwarding tags are deliberately excluded.
"""
general_tag_signatures() = _GENERAL_TAG_SIGNATURES
