"""
    ProtocolAttachment

The network scope that owns a protocol process:

- `NetworkAttachment` for a network-wide process,
- `NodeAttachment` for one owning node, and
- `EdgeAttachment` for one ordered owning edge.

Other participating nodes are represented separately by
[`ProtocolNodeRole`](@ref).
"""
@enum ProtocolAttachment::UInt8 begin
    NetworkAttachment
    NodeAttachment
    EdgeAttachment
end

"""
    ProtocolNodeCardinality

Whether a protocol node role names one node (`OneNode`) or an ordered collection
of nodes (`ManyNodes`).
"""
@enum ProtocolNodeCardinality::UInt8 begin
    OneNode
    ManyNodes
end

"""
    ProtocolNodeBinding

How a protocol node role is supplied:

- `AttachmentBound` roles define the node or edge that owns the process and are
  injected by attachment-aware tooling.
- `Configurable` roles are ordinary advertised constructor fields.
"""
@enum ProtocolNodeBinding::UInt8 begin
    AttachmentBound
    Configurable
end

"""
    ProtocolNodeRole(name, cardinality, binding)

Stable metadata for a protocol struct field that identifies one or many
participating network nodes.
"""
struct ProtocolNodeRole
    name::Symbol
    cardinality::ProtocolNodeCardinality
    binding::ProtocolNodeBinding
end

"""
    ProtocolSchema

Stable metadata for a protocol constructor, attachment, and node roles.

`constructor` describes only user-configurable protocol parameters. Simulator,
network, attachment-bound, and private runtime fields are deliberately excluded.
Configurable node roles remain constructor fields so their types, requiredness,
and documentation have one owner.
"""
struct ProtocolSchema
    constructor::ConstructorSchema
    attachment::ProtocolAttachment
    node_roles::Tuple{Vararg{ProtocolNodeRole}}
    permits_virtual_edge::Bool

    function ProtocolSchema(
        constructor::ConstructorSchema,
        attachment::ProtocolAttachment,
        node_roles::Tuple{Vararg{ProtocolNodeRole}},
        permits_virtual_edge::Bool=false,
    )
        protocol = constructor.constructor
        protocol <: AbstractProtocol ||
            throw(ArgumentError("$protocol is not an AbstractProtocol subtype"))

        attachment_roles = filter(
            role -> role.binding === AttachmentBound,
            node_roles,
        )
        expected_attachment_roles = if attachment === NetworkAttachment
            0
        elseif attachment === NodeAttachment
            1
        else
            2
        end
        length(attachment_roles) == expected_attachment_roles ||
            throw(ArgumentError(
                "$attachment requires $expected_attachment_roles AttachmentBound roles",
            ))
        all(role -> role.cardinality === OneNode, attachment_roles) ||
            throw(ArgumentError(
                "attachment-bound protocol node roles must identify one node",
            ))
        role_names = map(role -> role.name, node_roles)
        allunique(role_names) ||
            throw(ArgumentError("protocol node roles must be unique"))
        all(name -> name in fieldnames(protocol), role_names) ||
            throw(ArgumentError("protocol node roles must belong to $protocol"))
        for role in node_roles
            expected_type = role.cardinality === OneNode ? Int : Vector{Int}
            fieldtype(protocol, role.name) === expected_type ||
                throw(ArgumentError(
                    "node role $(role.name) must have declared type $expected_type",
                ))
        end
        parameter_names = map(field -> field.name, constructor.fields)
        for role in node_roles
            is_parameter = role.name in parameter_names
            if role.binding === AttachmentBound && is_parameter
                throw(ArgumentError(
                    "attachment-bound node roles cannot also be constructor parameters",
                ))
            elseif role.binding === Configurable && !is_parameter
                throw(ArgumentError(
                    "configurable node roles must be constructor parameters",
                ))
            end
        end
        permits_virtual_edge && attachment !== EdgeAttachment &&
            throw(ArgumentError(
                "only edge-attached protocols can permit virtual edges",
            ))

        return new(
            constructor,
            attachment,
            node_roles,
            permits_virtual_edge,
        )
    end
end

_attached_node(name::Symbol) =
    ProtocolNodeRole(name, OneNode, AttachmentBound)
_configurable_node(name::Symbol) =
    ProtocolNodeRole(name, OneNode, Configurable)
_configurable_nodes(name::Symbol) =
    ProtocolNodeRole(name, ManyNodes, Configurable)

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
    EdgeAttachment,
    (_attached_node(:nodeA), _attached_node(:nodeB)),
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
    NodeAttachment,
    (_attached_node(:node),),
)

const _ENTANGLEMENT_TRACKER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        EntanglementTracker,
        "Track remote pair metadata and swap corrections at one node.",
    ),
    NodeAttachment,
    (_attached_node(:node),),
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
    EdgeAttachment,
    (_attached_node(:nodeA), _attached_node(:nodeB)),
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
    NodeAttachment,
    (_attached_node(:node),),
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
    NodeAttachment,
    (
        _attached_node(:switchnode),
        _configurable_nodes(:clientnodes),
    ),
)

const _END_NODE_CONTROLLER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        EndNodeController,
        "Manage QTCP control signals at an endpoint node.",
    ),
    NodeAttachment,
    (_attached_node(:node),),
)

const _NETWORK_NODE_CONTROLLER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        NetworkNodeController,
        "Route QTCP traffic and swaps at an intermediate node.",
    ),
    NodeAttachment,
    (_attached_node(:node),),
)

const _LINK_CONTROLLER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        LinkController,
        "Establish link-level entanglement for QTCP between adjacent nodes.",
    ),
    EdgeAttachment,
    (_attached_node(:nodeA), _attached_node(:nodeB)),
)

const _GRAPH_STATE_CONSTRUCTOR_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        GraphStateConstructor,
        "Construct a graph state across a configurable set of network nodes.",
        (
            _constructor_field(
                GraphStateConstructor,
                :graph,
                "Graph whose vertices correspond to the ordered node role.";
                required=true,
            ),
            _constructor_field(
                GraphStateConstructor,
                :nodes,
                "Ordered network nodes that store the graph-state vertices.";
                required=true,
            ),
            _constructor_field(
                GraphStateConstructor,
                :communication_slot,
                "Slot used to generate pairwise entanglement.";
                required=true,
            ),
            _constructor_field(
                GraphStateConstructor,
                :storage_slot,
                "Slot used to store each graph-state qubit.";
                required=true,
            ),
        ),
    ),
    NetworkAttachment,
    (_configurable_nodes(:nodes),),
)

const _GRAPH_TO_RESOURCE_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        GraphToResource,
        "Convert a distributed graph state to a stabilizer resource state.",
        (
            _constructor_field(
                GraphToResource,
                :nodes,
                "Ordered network nodes that store the distributed state.";
                required=true,
            ),
            _constructor_field(
                GraphToResource,
                :slot,
                "Slot at each node that stores the graph-state qubit.";
                required=true,
            ),
            _constructor_field(
                GraphToResource,
                :hadamard_idx,
                "Node-role indices receiving Hadamard corrections.";
                required=true,
            ),
            _constructor_field(
                GraphToResource,
                :iphase_idx,
                "Node-role indices receiving inverse-phase corrections.";
                required=true,
            ),
            _constructor_field(
                GraphToResource,
                :flips_idx,
                "Node-role indices receiving Z corrections.";
                required=true,
            ),
        ),
    ),
    NetworkAttachment,
    (_configurable_nodes(:nodes),),
)

const _PURIFIER_BELL_MEASUREMENTS_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        PurifierBellMeasurements,
        "Measure local purifier pairs and send packed results to a remote chief.",
        (
            _constructor_field(
                PurifierBellMeasurements,
                :nodes,
                "Ordered local nodes at which Bell measurements are performed.";
                required=true,
            ),
            _constructor_field(
                PurifierBellMeasurements,
                :remote_chief_idx,
                "Remote chief node that receives the packed result.";
                required=true,
            ),
            _constructor_field(
                PurifierBellMeasurements,
                :x_slot,
                "Shared slot on which X measurements are performed.";
                required=true,
            ),
            _constructor_field(
                PurifierBellMeasurements,
                :z_slot,
                "Shared slot on which Z measurements are performed.";
                required=true,
            ),
        ),
    ),
    NodeAttachment,
    (
        _configurable_nodes(:nodes),
        _attached_node(:local_chief_idx),
        _configurable_node(:remote_chief_idx),
    ),
)

const _MBQC_PURIFICATION_TRACKER_SCHEMA = ProtocolSchema(
    _protocol_constructor(
        MBQCPurificationTracker,
        "Track local and remote MBQC purification outcomes at one chief node.",
        (
            _constructor_field(
                MBQCPurificationTracker,
                :nodes,
                "Ordered local nodes that store resource and purified pairs.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :n,
                "Number of initial Bell pairs in the resource state.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :remote_chief_idx,
                "Remote chief node whose measurement results are tracked.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :H1,
                "X parity-check matrix for the purification code.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :H2,
                "Z parity-check matrix for the purification code.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :logxs,
                "Logical X operators for the purification code.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :logzs,
                "Logical Z operators for the purification code.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :communication_slot,
                "Slot used for initial pair entanglement.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :storage_slot,
                "Slot used for resource and purified state storage.";
                required=true,
            ),
            _constructor_field(
                MBQCPurificationTracker,
                :correct,
                "Whether to apply logical correction operations.";
                required=false,
            ),
        ),
    ),
    NodeAttachment,
    (
        _configurable_nodes(:nodes),
        _attached_node(:local_chief_idx),
        _configurable_node(:remote_chief_idx),
    ),
)

"""
    protocol_schema(::Type{<:AbstractProtocol})

Return stable, simulator-owned constructor, attachment, and node-role metadata
for a supported protocol. Packages defining custom protocols can add a method
for their protocol type.
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
protocol_schema(::Type{GraphStateConstructor}) =
    _GRAPH_STATE_CONSTRUCTOR_SCHEMA
protocol_schema(::Type{GraphToResource}) = _GRAPH_TO_RESOURCE_SCHEMA
protocol_schema(::Type{PurifierBellMeasurements}) =
    _PURIFIER_BELL_MEASUREMENTS_SCHEMA
protocol_schema(::Type{MBQCPurificationTracker}) =
    _MBQC_PURIFICATION_TRACKER_SCHEMA

QuantumSavory.constructor_schema(::Type{T}) where {T<:AbstractProtocol} =
    protocol_schema(T).constructor

"""
    protocol_attachment(::Type{<:AbstractProtocol})
    protocol_attachment(::AbstractProtocol)

Return the network attachment for a protocol. Custom protocols without
an explicit schema are not introspectable.
"""
protocol_attachment(type::Type{<:AbstractProtocol}) =
    protocol_schema(type).attachment
protocol_attachment(protocol::AbstractProtocol) =
    protocol_attachment(typeof(protocol))

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
        _GRAPH_STATE_CONSTRUCTOR_SCHEMA,
        _GRAPH_TO_RESOURCE_SCHEMA,
        _PURIFIER_BELL_MEASUREMENTS_SCHEMA,
        _MBQC_PURIFICATION_TRACKER_SCHEMA,
    )
end
