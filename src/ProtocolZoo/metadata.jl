"""
    ProtocolPlacement

The network placement required by a protocol:

- `FloatingProtocolPlacement` for no fixed node,
- `NodeProtocolPlacement` for one node, and
- `EdgeProtocolPlacement` for an ordered pair of nodes.
"""
@enum ProtocolPlacement::UInt8 begin
    FloatingProtocolPlacement
    NodeProtocolPlacement
    EdgeProtocolPlacement
end

"""
    ProtocolSchema

Stable metadata for a protocol constructor and its network placement.

`constructor` describes only user-configurable protocol parameters. Simulator,
network, placement, and private runtime fields are deliberately excluded.
`placement_fields` names the fields that carry the node or edge placement.
"""
struct ProtocolSchema
    constructor::ConstructorSchema
    placement::ProtocolPlacement
    placement_fields::Tuple{Vararg{Symbol}}
    permits_virtual_edge::Bool

    function ProtocolSchema(
        constructor::ConstructorSchema,
        placement::ProtocolPlacement,
        placement_fields::Tuple{Vararg{Symbol}},
        permits_virtual_edge::Bool=false,
    )
        protocol = constructor.constructor
        protocol <: AbstractProtocol ||
            throw(ArgumentError("$protocol is not an AbstractProtocol subtype"))

        expected_fields = if placement === FloatingProtocolPlacement
            0
        elseif placement === NodeProtocolPlacement
            1
        else
            2
        end
        length(placement_fields) == expected_fields ||
            throw(ArgumentError(
                "$placement requires $expected_fields placement fields",
            ))
        allunique(placement_fields) ||
            throw(ArgumentError("protocol placement fields must be unique"))
        all(name -> name in fieldnames(protocol), placement_fields) ||
            throw(ArgumentError(
                "protocol placement fields must belong to $protocol",
            ))
        parameter_names = map(field -> field.name, constructor.fields)
        isempty(intersect(placement_fields, parameter_names)) ||
            throw(ArgumentError(
                "protocol placement fields cannot also be constructor parameters",
            ))
        permits_virtual_edge && placement !== EdgeProtocolPlacement &&
            throw(ArgumentError(
                "only edge protocols can permit virtual edges",
            ))

        return new(
            constructor,
            placement,
            placement_fields,
            permits_virtual_edge,
        )
    end
end

function _protocol_constructor(
    protocol::Type,
    doc::AbstractString,
    fields::Tuple{Vararg{ConstructorFieldSchema}}=(),
)
    return ConstructorSchema(protocol, doc, fields)
end

const _ENTANGLER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        EntanglerProt,
        "Generate entanglement between two network nodes.",
        (
            _constructor_field(
                EntanglerProt,
                :pairstate,
                "State generated after a successful attempt.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :success_prob,
                "Success probability for one generation attempt.";
                required=false,
                minimum=0.0,
                maximum=1.0,
            ),
            _constructor_field(
                EntanglerProt,
                :attempt_time,
                "Duration of one generation attempt.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :local_busy_time_pre,
                "Local busy time before generation attempts.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :local_busy_time_post,
                "Local busy time after a successful attempt.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :retry_lock_time,
                "Delay before retrying unavailable slot locks, or `nothing`.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :rounds,
                "Number of rounds, with `-1` meaning indefinitely.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :attempts,
                "Maximum attempts per round, with `-1` meaning indefinitely.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :chooseslotA,
                "Slot selector for the first node.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :chooseslotB,
                "Slot selector for the second node.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :randomize,
                "Whether to randomize the free-slot search.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :uselock,
                "Whether to lock selected slots during generation.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :margin,
                "Slots to leave free after entanglement already exists.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :hardmargin,
                "Slots to leave free before entanglement exists.";
                required=false,
            ),
            _constructor_field(
                EntanglerProt,
                :tag,
                "Tag-head type added to generated pairs, or `nothing`.";
                required=false,
            ),
        ),
    ),
    EdgeProtocolPlacement,
    (:nodeA, :nodeB),
)

const _SWAPPER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        SwapperProt,
        "Swap two entangled pairs at one network node.",
        (
            _constructor_field(
                SwapperProt,
                :chooseslots,
                "Selector for eligible local slots.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :nodeL,
                "Query selecting one remote counterpart.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :nodeH,
                "Query selecting the other remote counterpart.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :chooseL,
                "Chooser among matches for `nodeL`.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :chooseH,
                "Chooser among matches for `nodeH`.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :local_busy_time,
                "Local busy time before the swap.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :retry_lock_time,
                "Delay before retrying unavailable slots, or `nothing`.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :rounds,
                "Number of rounds, with `-1` meaning indefinitely.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :agelimit,
                "Maximum eligible pair age, or `nothing`.";
                required=false,
            ),
            _constructor_field(
                SwapperProt,
                :max_history_per_slot,
                "Retained history-tag limit, or `nothing`.";
                required=false,
            ),
        ),
    ),
    NodeProtocolPlacement,
    (:node,),
)

const _ENTANGLEMENT_TRACKER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        EntanglementTracker,
        "Track remote pair metadata and swap corrections at one node.",
    ),
    NodeProtocolPlacement,
    (:node,),
)

const _ENTANGLEMENT_CONSUMER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        EntanglementConsumer,
        "Consume completed entanglement between two nodes.",
        (
            _constructor_field(
                EntanglementConsumer,
                :period,
                "Polling period, or `nothing` to wait for tag changes.";
                required=false,
            ),
            _constructor_field(
                EntanglementConsumer,
                :tag,
                "Tag-head type identifying consumable pairs.";
                required=false,
            ),
        ),
    ),
    EdgeProtocolPlacement,
    (:nodeA, :nodeB),
    true,
)

const _CUTOFF_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        CutoffProt,
        "Remove entanglement older than a retention threshold at one node.",
        (
            _constructor_field(
                CutoffProt,
                :period,
                "Polling period, or `nothing` to wait for tag changes.";
                required=false,
            ),
            _constructor_field(
                CutoffProt,
                :retention_time,
                "Age after which an entangled slot is emptied.";
                required=false,
            ),
            _constructor_field(
                CutoffProt,
                :announce,
                "Whether to notify the remote counterpart after deletion.";
                required=false,
            ),
            _constructor_field(
                CutoffProt,
                :max_delete_per_slot,
                "Retained deletion-tag limit, or `nothing`.";
                required=false,
            ),
        ),
    ),
    NodeProtocolPlacement,
    (:node,),
)

const _SIMPLE_SWITCH_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        SimpleSwitchDiscreteProt,
        "Serve client-pair requests from one discrete-time switch node.",
        (
            _constructor_field(
                SimpleSwitchDiscreteProt,
                :clientnodes,
                "Client node indices served by the switch.";
                required=true,
            ),
            _constructor_field(
                SimpleSwitchDiscreteProt,
                :success_probs,
                "Per-client raw-entanglement success probabilities.";
                required=true,
            ),
            _constructor_field(
                SimpleSwitchDiscreteProt,
                :ticktock,
                "Duration of one switching cycle.";
                required=false,
            ),
            _constructor_field(
                SimpleSwitchDiscreteProt,
                :rounds,
                "Number of cycles, with `-1` meaning indefinitely.";
                required=false,
            ),
            _constructor_field(
                SimpleSwitchDiscreteProt,
                :assignment_algorithm,
                "Memory-slot assignment algorithm.";
                required=false,
            ),
        ),
    ),
    NodeProtocolPlacement,
    (:switchnode,),
)

const _END_NODE_CONTROLLER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        EndNodeController,
        "Manage QTCP control signals at an endpoint node.",
    ),
    NodeProtocolPlacement,
    (:node,),
)

const _NETWORK_NODE_CONTROLLER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        NetworkNodeController,
        "Route QTCP traffic and swaps at an intermediate node.",
    ),
    NodeProtocolPlacement,
    (:node,),
)

const _LINK_CONTROLLER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        LinkController,
        "Establish link-level entanglement for QTCP between adjacent nodes.",
    ),
    EdgeProtocolPlacement,
    (:nodeA, :nodeB),
)

"""
    protocol_schema(::Type{<:AbstractProtocol})

Return stable, simulator-owned constructor and placement metadata for a
supported protocol. Packages defining custom protocols can add a method for
their protocol type.
"""
function protocol_schema(::Type{T}) where {T<:AbstractProtocol}
    throw(ArgumentError("no protocol schema is registered for $T"))
end
protocol_schema(protocol::AbstractProtocol) = protocol_schema(typeof(protocol))

protocol_schema(::Type{EntanglerProt}) = _ENTANGLER_SCHEMA
protocol_schema(::Type{SwapperProt}) = _SWAPPER_SCHEMA
protocol_schema(::Type{EntanglementTracker}) = _ENTANGLEMENT_TRACKER_SCHEMA
protocol_schema(::Type{EntanglementConsumer}) = _ENTANGLEMENT_CONSUMER_SCHEMA
protocol_schema(::Type{CutoffProt}) = _CUTOFF_SCHEMA
protocol_schema(::Type{SimpleSwitchDiscreteProt}) = _SIMPLE_SWITCH_SCHEMA
protocol_schema(::Type{EndNodeController}) = _END_NODE_CONTROLLER_SCHEMA
protocol_schema(::Type{NetworkNodeController}) =
    _NETWORK_NODE_CONTROLLER_SCHEMA
protocol_schema(::Type{LinkController}) = _LINK_CONTROLLER_SCHEMA

QuantumSavory.constructor_schema(::Type{T}) where {T<:AbstractProtocol} =
    protocol_schema(T).constructor

"""
    protocol_placement(::Type{<:AbstractProtocol})
    protocol_placement(::AbstractProtocol)

Return the network-placement category for a protocol. Custom protocols without
an explicit schema are not introspectable.
"""
protocol_placement(type::Type{<:AbstractProtocol}) =
    protocol_schema(type).placement
protocol_placement(protocol::AbstractProtocol) = protocol_placement(typeof(protocol))

"""
    permits_virtual_edge(::Type{<:AbstractProtocol})
    permits_virtual_edge(::AbstractProtocol)

Return whether a protocol can operate between nodes without a corresponding
physical graph edge. The capability is defined by [`protocol_schema`](@ref);
instance queries delegate to their type.
"""
permits_virtual_edge(type::Type{<:AbstractProtocol}) =
    protocol_schema(type).permits_virtual_edge
permits_virtual_edge(protocol::AbstractProtocol) =
    permits_virtual_edge(typeof(protocol))

"""
    protocol_schemas()

Return the explicit, deterministic catalog of built-in public protocols.
Loading unrelated packages or defining custom subtypes does not change it.
"""
function protocol_schemas()
    return (
        _ENTANGLER_SCHEMA,
        _SWAPPER_SCHEMA,
        _ENTANGLEMENT_TRACKER_SCHEMA,
        _ENTANGLEMENT_CONSUMER_SCHEMA,
        _CUTOFF_SCHEMA,
        _SIMPLE_SWITCH_SCHEMA,
        _END_NODE_CONTROLLER_SCHEMA,
        _NETWORK_NODE_CONTROLLER_SCHEMA,
        _LINK_CONTROLLER_SCHEMA,
    )
end
