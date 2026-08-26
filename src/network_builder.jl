"""
    dist_to_delay(distance_m::Real, speed_m_per_s::Real=2.0e8)
    dist_to_delay(distances::AbstractDict, speed_m_per_s::Real=2.0e8)

Convert a distance in metres to a one-way propagation delay in seconds. The
dictionary method returns a new `Dict` with the same edge keys and converted
values.

Distances must be finite and nonnegative. The propagation speed must be finite
and positive. The computed delay must also be finite.

```jldoctest
julia> dist_to_delay(200_000_000)
1.0

julia> using Graphs

julia> dist_to_delay(Dict(Edge(1, 2) => 100_000_000))[Edge(1, 2)]
0.5
```
"""
function dist_to_delay(distance_m::Real, speed_m_per_s::Real=2.0e8)
    isfinite(distance_m) && distance_m >= 0 || throw(DomainError(
        distance_m,
        "distance_m must be finite and nonnegative",
    ))
    isfinite(speed_m_per_s) && speed_m_per_s > 0 || throw(DomainError(
        speed_m_per_s,
        "speed_m_per_s must be finite and positive",
    ))
    delay = distance_m / speed_m_per_s
    isfinite(delay) || throw(DomainError(
        (distance_m, speed_m_per_s),
        "distance_m / speed_m_per_s must be finite",
    ))
    return delay
end

function dist_to_delay(distances::AbstractDict, speed_m_per_s::Real=2.0e8)
    isfinite(speed_m_per_s) && speed_m_per_s > 0 || throw(DomainError(
        speed_m_per_s,
        "speed_m_per_s must be finite and positive",
    ))
    return Dict(edge => dist_to_delay(distance_m, speed_m_per_s) for
                (edge, distance_m) in distances)
end

function _network_builder_error(message)
    throw(ArgumentError("network_builder: $(message)"))
end

function _validate_protocol_specification(specification, expected_attachment)
    specification isa Pair || _network_builder_error(
        "each protocol specification must be `ProtocolType => NamedTuple`",
    )
    protocol_type, configured = specification
    protocol_type isa Type &&
        protocol_type <: ProtocolZoo.AbstractProtocol &&
        isconcretetype(protocol_type) || _network_builder_error(
            "$(repr(protocol_type)) must be a concrete subtype of ProtocolZoo.AbstractProtocol",
        )
    configured isa NamedTuple || _network_builder_error(
        "the configuration for $(protocol_type) must be a NamedTuple",
    )
    applicable(ProtocolZoo.protocol_catalog_metadata, protocol_type) ||
        _network_builder_error(
            "$(protocol_type) is not available through ProtocolZoo.protocol_catalog_metadata",
        )

    metadata = ProtocolZoo.protocol_catalog_metadata(protocol_type)
    expected_keys = (:attachment, :attachment_fields, :required_fields)
    metadata isa NamedTuple && keys(metadata) == expected_keys ||
        _network_builder_error(
            "catalog metadata for $(protocol_type) must be a NamedTuple with fields $(expected_keys)",
        )

    attachment = metadata.attachment
    attachment in (:network, :node, :edge) || _network_builder_error(
        "catalog metadata for $(protocol_type) has invalid attachment $(repr(attachment))",
    )
    attachment == expected_attachment || _network_builder_error(
        "$(protocol_type) is attached to $(repr(attachment)), not $(repr(expected_attachment))",
    )

    attachment_fields = metadata.attachment_fields
    expected_roles = attachment === :network ? () :
                     attachment === :node ? (:node,) :
                     (:node_a, :node_b)
    attachment_fields isa NamedTuple && keys(attachment_fields) == expected_roles ||
        _network_builder_error(
            "catalog metadata for $(protocol_type) must map attachment roles $(expected_roles)",
        )
    mapped_fields = Tuple(values(attachment_fields))
    all(field -> field isa Symbol, mapped_fields) || _network_builder_error(
        "catalog attachment fields for $(protocol_type) must be Symbols",
    )
    allunique(mapped_fields) || _network_builder_error(
        "catalog attachment fields for $(protocol_type) must be unique",
    )

    constructor_fields = fieldnames(protocol_type)
    for field in (:sim, :net)
        field in constructor_fields || _network_builder_error(
            "cataloged protocol $(protocol_type) must define the injected field $(repr(field))",
        )
    end
    for field in mapped_fields
        field in constructor_fields || _network_builder_error(
            "catalog attachment field $(repr(field)) is not a field of $(protocol_type)",
        )
        field in (:sim, :net) && _network_builder_error(
            "catalog attachment fields cannot use framework-injected field $(repr(field))",
        )
        startswith(String(field), "_") && _network_builder_error(
            "catalog attachment fields cannot use private field $(repr(field))",
        )
    end

    required_fields = metadata.required_fields
    required_fields isa Tuple && all(field -> field isa Symbol, required_fields) ||
        _network_builder_error(
            "catalog required_fields for $(protocol_type) must be a tuple of Symbols",
        )
    allunique(required_fields) || _network_builder_error(
        "catalog required_fields for $(protocol_type) must be unique",
    )

    configurable_fields = filter(constructor_fields) do field
        field ∉ (:sim, :net) &&
            field ∉ mapped_fields &&
            !startswith(String(field), "_")
    end
    all(field -> field in configurable_fields, required_fields) ||
        _network_builder_error(
            "catalog required_fields for $(protocol_type) must name configurable fields",
        )

    for field in keys(configured)
        if field in (:sim, :net) || field in mapped_fields
            _network_builder_error(
                "field $(repr(field)) of $(protocol_type) is supplied by network_builder",
            )
        elseif startswith(String(field), "_")
            _network_builder_error(
                "private field $(repr(field)) of $(protocol_type) is not configurable",
            )
        elseif field ∉ configurable_fields
            _network_builder_error(
                "unknown configurable field $(repr(field)) for $(protocol_type)",
            )
        end
    end
    missing_fields = filter(field -> field ∉ keys(configured), required_fields)
    isempty(missing_fields) || _network_builder_error(
        "configuration for $(protocol_type) is missing required fields $(Tuple(missing_fields))",
    )

    return (; protocol_type, configured, attachment_fields)
end

function _validate_protocol_specifications(specifications, expected_attachment)
    specifications = specifications isa Pair ? (specifications,) : specifications
    applicable(iterate, specifications) ||
        _network_builder_error("protocol specifications must be iterable")
    return [
        _validate_protocol_specification(specification, expected_attachment)
        for specification in specifications
    ]
end

function _attachment_keywords(attachment_fields, values)
    fields = Tuple(attachment_fields)
    return NamedTuple{fields}(values)
end

"""
    network_builder(
        graph::SimpleGraph,
        delays::AbstractDict,
        register_args::Tuple;
        node_protocols=(),
        link_protocols=(),
    ) -> (; sim, network)

Build a register network for `graph` without running its simulation. One
nonempty `Register(register_args...)` is created per vertex. `delays` must have
exactly one finite, nonnegative value for every undirected graph edge; that
value is used for both directions of both the classical and quantum channels.

Each protocol specification is a `ProtocolType => NamedTuple`. Node protocol
types must have `:node` attachment metadata and are instantiated on every
vertex. Link protocol types must have `:edge` attachment metadata and are
instantiated on every undirected edge. `sim`, `net`, and the catalog-mapped
attachment fields are injected by the builder. All protocols are instantiated
before any protocol is scheduled.

```jldoctest
julia> using Graphs

julia> graph = path_graph(3);

julia> delays = Dict(edge => 0.01 for edge in edges(graph));

julia> result = network_builder(graph, delays, (2,));

julia> (nv(result.network), length(result.network[1]))
(3, 2)
```
"""
function network_builder(
    graph::SimpleGraph,
    delays::AbstractDict,
    register_args::Tuple;
    node_protocols=(),
    link_protocols=(),
)
    nv(graph) > 0 || _network_builder_error("graph must contain at least one vertex")

    graph_edges = Set(edges(graph))
    delay_edges = Set(keys(delays))
    graph_edges == delay_edges || _network_builder_error(
        "delay keys must exactly match the graph edges",
    )
    edge_delays = Dict(
        Edge(Int(edge.src), Int(edge.dst)) => begin
            delay = delays[edge]
            delay isa Real && isfinite(delay) && delay >= 0 || _network_builder_error(
                "delay for $(edge) must be finite and nonnegative",
            )
            normalized_delay = try
                Float64(delay)
            catch
                _network_builder_error(
                    "delay for $(edge) must be representable as a finite Float64",
                )
            end
            isfinite(normalized_delay) || _network_builder_error(
                "delay for $(edge) must be representable as a finite Float64",
            )
            normalized_delay
        end
        for edge in edges(graph)
    )

    validated_node_protocols = _validate_protocol_specifications(node_protocols, :node)
    validated_link_protocols = _validate_protocol_specifications(link_protocols, :edge)

    topology = SimpleGraph{Int}(graph)
    registers = [Register(register_args...) for _ in vertices(topology)]
    all(!isempty, registers) || _network_builder_error(
        "Register(register_args...) must contain at least one slot",
    )
    edge_delay(src, dst) = edge_delays[Edge(minmax(src, dst)...)]
    network = RegisterNet(
        topology,
        registers;
        classical_delay=edge_delay,
        quantum_delay=edge_delay,
    )
    sim = get_time_tracker(network)

    protocols = ProtocolZoo.AbstractProtocol[]
    for specification in validated_node_protocols
        attachment_field = only(values(specification.attachment_fields))
        for node in vertices(topology)
            attachment = _attachment_keywords((attachment_field,), (node,))
            push!(protocols, specification.protocol_type(;
                sim,
                net=network,
                attachment...,
                specification.configured...,
            ))
        end
    end
    for specification in validated_link_protocols
        attachment_fields = Tuple(values(specification.attachment_fields))
        for (; src, dst) in edges(topology)
            attachment = _attachment_keywords(attachment_fields, (src, dst))
            push!(protocols, specification.protocol_type(;
                sim,
                net=network,
                attachment...,
                specification.configured...,
            ))
        end
    end

    for protocol in protocols
        @process protocol()
    end
    return (; sim, network)
end
