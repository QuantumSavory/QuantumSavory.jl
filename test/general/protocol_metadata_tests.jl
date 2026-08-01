using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation:
    GraphStateConstructor,
    GraphToResource,
    PurifierBellMeasurements,
    MBQCPurificationTracker
using Graphs: complete_graph
using QuantumClifford: Stabilizer

struct CustomNetworkProtocol <: AbstractProtocol
    value::Int
end

QuantumSavory.ProtocolZoo.protocol_schema(::Type{CustomNetworkProtocol}) =
    ProtocolSchema(
        ConstructorSchema(
            CustomNetworkProtocol,
            "A test-only network-attached protocol.",
            (
                ConstructorFieldSchema(
                    :value,
                    Int,
                    "A test value.";
                    required=true,
                ),
            ),
        ),
        NetworkAttachment,
        (),
    )

struct CustomVirtualEdgeProtocol <: AbstractProtocol
    nodeA::Int
    nodeB::Int
end

QuantumSavory.ProtocolZoo.protocol_schema(
    ::Type{CustomVirtualEdgeProtocol},
) = ProtocolSchema(
    ConstructorSchema(
        CustomVirtualEdgeProtocol,
        "A test-only virtual-edge protocol.",
    ),
    EdgeAttachment,
    (
        ProtocolNodeRole(:nodeA, OneNode, AttachmentBound),
        ProtocolNodeRole(:nodeB, OneNode, AttachmentBound),
    ),
    true,
)

struct InvalidNodeProtocol <: AbstractProtocol
    node::Int
end

struct InvalidNodeListProtocol <: AbstractProtocol
    nodes::Int
end

struct MissingConfigurableRoleProtocol <: AbstractProtocol
    nodes::Vector{Int}
end

function exported_protocol_types(modules)
    protocols = Set{DataType}()
    for mod in modules, name in names(mod)
        isdefined(mod, name) || continue
        value = getfield(mod, name)
        value isa DataType || continue
        isconcretetype(value) || continue
        value <: AbstractProtocol || continue
        push!(protocols, value)
    end
    return protocols
end

role_contract(schema) = map(
    role -> (role.name, role.cardinality, role.binding),
    schema.node_roles,
)

@testset "Protocol metadata" begin
    expected_protocols = (
        EntanglerProt,
        SwapperProt,
        EntanglementTracker,
        EntanglementConsumer,
        CutoffProt,
        SimpleSwitchDiscreteProt,
        EndNodeController,
        NetworkNodeController,
        LinkController,
        GraphStateConstructor,
        GraphToResource,
        PurifierBellMeasurements,
        MBQCPurificationTracker,
    )

    schemas = protocol_schemas()
    @test schemas isa Tuple
    @test fieldnames(ProtocolSchema) == (
        :constructor,
        :attachment,
        :node_roles,
        :permits_virtual_edge,
    )
    @test map(schema -> schema.constructor.constructor, schemas) ==
          expected_protocols
    @test exported_protocol_types((
        QuantumSavory.ProtocolZoo,
        QuantumSavory.ProtocolZoo.Switches,
        QuantumSavory.ProtocolZoo.QTCP,
        QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation,
    )) == Set(expected_protocols)

    net = RegisterNet(complete_graph(3), [Register(1) for _ in 1:3])
    sim = get_time_tracker(net)
    graph = complete_graph(2)
    empty_stabilizer = Stabilizer(falses(1, 2))

    function required_constructor_arguments(protocol)
        if protocol === SimpleSwitchDiscreteProt
            return (
                clientnodes=[2, 3],
                success_probs=[0.5, 0.5],
            )
        elseif protocol === GraphStateConstructor
            return (
                graph,
                nodes=[1, 2],
                communication_slot=1,
                storage_slot=1,
            )
        elseif protocol === GraphToResource
            return (
                nodes=[1, 2],
                slot=1,
                hadamard_idx=Int[],
                iphase_idx=Int[],
                flips_idx=Int[],
            )
        elseif protocol === PurifierBellMeasurements
            return (
                nodes=[1, 2],
                remote_chief_idx=2,
                x_slot=1,
                z_slot=1,
            )
        elseif protocol === MBQCPurificationTracker
            return (
                nodes=[1, 2],
                n=1,
                remote_chief_idx=2,
                H1=zeros(Int, 1, 1),
                H2=zeros(Int, 1, 1),
                logxs=empty_stabilizer,
                logzs=empty_stabilizer,
                communication_slot=1,
                storage_slot=1,
            )
        end
        return NamedTuple()
    end

    for schema in schemas
        protocol = schema.constructor.constructor
        @test protocol_schema(protocol) === schema
        @test constructor_schema(protocol) === schema.constructor
        @test protocol_attachment(protocol) === schema.attachment
        @test permits_virtual_edge(protocol) === schema.permits_virtual_edge
        @test !isempty(schema.constructor.doc)

        parameter_names = map(field -> field.name, schema.constructor.fields)
        role_names = map(role -> role.name, schema.node_roles)
        attachment_names = map(
            role -> role.name,
            filter(
                role -> role.binding === AttachmentBound,
                schema.node_roles,
            ),
        )
        @test all(name -> name in fieldnames(protocol), role_names)
        @test isempty(intersect(
            parameter_names,
            (
                :sim,
                :net,
                attachment_names...,
                :_log,
                :_backlog,
            ),
        ))

        for role in schema.node_roles
            expected_type = role.cardinality === OneNode ? Int : Vector{Int}
            @test fieldtype(protocol, role.name) === expected_type
            @test (role.name in parameter_names) ===
                  (role.binding === Configurable)
        end
        for field in schema.constructor.fields
            @test field.declared_type === fieldtype(protocol, field.name)
            @test !isempty(field.doc)
        end

        attachment_arguments = NamedTuple{attachment_names}(
            ntuple(identity, length(attachment_names)),
        )
        required = required_constructor_arguments(protocol)
        baseline = protocol(; sim, net, attachment_arguments..., required...)
        advertised = (; map(
            field -> field.name => getfield(baseline, field.name),
            schema.constructor.fields,
        )...)
        @test protocol(;
            sim,
            net,
            attachment_arguments...,
            advertised...,
        ) isa protocol
    end

    @test map(protocol_attachment, expected_protocols) == (
        EdgeAttachment,
        NodeAttachment,
        NodeAttachment,
        EdgeAttachment,
        NodeAttachment,
        NodeAttachment,
        NodeAttachment,
        NodeAttachment,
        EdgeAttachment,
        NetworkAttachment,
        NetworkAttachment,
        NodeAttachment,
        NodeAttachment,
    )
    @test map(role_contract, schemas) == (
        (
            (:nodeA, OneNode, AttachmentBound),
            (:nodeB, OneNode, AttachmentBound),
        ),
        ((:node, OneNode, AttachmentBound),),
        ((:node, OneNode, AttachmentBound),),
        (
            (:nodeA, OneNode, AttachmentBound),
            (:nodeB, OneNode, AttachmentBound),
        ),
        ((:node, OneNode, AttachmentBound),),
        (
            (:switchnode, OneNode, AttachmentBound),
            (:clientnodes, ManyNodes, Configurable),
        ),
        ((:node, OneNode, AttachmentBound),),
        ((:node, OneNode, AttachmentBound),),
        (
            (:nodeA, OneNode, AttachmentBound),
            (:nodeB, OneNode, AttachmentBound),
        ),
        ((:nodes, ManyNodes, Configurable),),
        ((:nodes, ManyNodes, Configurable),),
        (
            (:nodes, ManyNodes, Configurable),
            (:local_chief_idx, OneNode, AttachmentBound),
            (:remote_chief_idx, OneNode, Configurable),
        ),
        (
            (:nodes, ManyNodes, Configurable),
            (:local_chief_idx, OneNode, AttachmentBound),
            (:remote_chief_idx, OneNode, Configurable),
        ),
    )

    entangler = protocol_schema(EntanglerProt)
    @test map(field -> field.name, entangler.constructor.fields) == (
        :pairstate,
        :success_prob,
        :attempt_time,
        :local_busy_time_pre,
        :local_busy_time_post,
        :retry_lock_time,
        :rounds,
        :attempts,
        :chooseslotA,
        :chooseslotB,
        :randomize,
        :uselock,
        :margin,
        :hardmargin,
        :tag,
    )
    @test constructor_constraints(EntanglerProt, Val(:success_prob)) ==
          (minimum=0.0, maximum=1.0)

    consumer = protocol_schema(EntanglementConsumer)
    @test consumer.attachment === EdgeAttachment
    @test consumer.permits_virtual_edge
    @test count(schema -> schema.permits_virtual_edge, schemas) == 1

    switch_schema = protocol_schema(SimpleSwitchDiscreteProt)
    @test switch_schema.attachment === NodeAttachment
    @test map(field -> field.name, switch_schema.constructor.fields)[1:2] ==
          (:clientnodes, :success_probs)

    @test map(
        field -> field.name,
        protocol_schema(GraphStateConstructor).constructor.fields,
    ) == (:graph, :nodes, :communication_slot, :storage_slot)
    @test map(
        field -> field.name,
        protocol_schema(GraphToResource).constructor.fields,
    ) == (:nodes, :slot, :hadamard_idx, :iphase_idx, :flips_idx)
    @test map(
        field -> field.name,
        protocol_schema(PurifierBellMeasurements).constructor.fields,
    ) == (:nodes, :remote_chief_idx, :x_slot, :z_slot)
    @test map(
        field -> field.name,
        protocol_schema(MBQCPurificationTracker).constructor.fields,
    ) == (
        :nodes,
        :n,
        :remote_chief_idx,
        :H1,
        :H2,
        :logxs,
        :logzs,
        :communication_slot,
        :storage_slot,
        :correct,
    )

    required_fields = [
        (schema.constructor.constructor, field.name)
        for schema in schemas for field in schema.constructor.fields
        if field.required
    ]
    @test required_fields == [
        (SimpleSwitchDiscreteProt, :clientnodes),
        (SimpleSwitchDiscreteProt, :success_probs),
        (GraphStateConstructor, :graph),
        (GraphStateConstructor, :nodes),
        (GraphStateConstructor, :communication_slot),
        (GraphStateConstructor, :storage_slot),
        (GraphToResource, :nodes),
        (GraphToResource, :slot),
        (GraphToResource, :hadamard_idx),
        (GraphToResource, :iphase_idx),
        (GraphToResource, :flips_idx),
        (PurifierBellMeasurements, :nodes),
        (PurifierBellMeasurements, :remote_chief_idx),
        (PurifierBellMeasurements, :x_slot),
        (PurifierBellMeasurements, :z_slot),
        (MBQCPurificationTracker, :nodes),
        (MBQCPurificationTracker, :n),
        (MBQCPurificationTracker, :remote_chief_idx),
        (MBQCPurificationTracker, :H1),
        (MBQCPurificationTracker, :H2),
        (MBQCPurificationTracker, :logxs),
        (MBQCPurificationTracker, :logzs),
        (MBQCPurificationTracker, :communication_slot),
        (MBQCPurificationTracker, :storage_slot),
    ]
    @test sum(length(schema.constructor.fields) for schema in schemas) == 59
    @test_throws UndefKeywordError SimpleSwitchDiscreteProt(;
        sim,
        net,
        switchnode=1,
    )
    @test_throws UndefKeywordError GraphStateConstructor(;
        sim,
        net,
        nodes=[1, 2],
        communication_slot=1,
        storage_slot=1,
    )

    custom = protocol_schema(CustomNetworkProtocol)
    @test custom.constructor.constructor === CustomNetworkProtocol
    @test protocol_attachment(CustomNetworkProtocol) === NetworkAttachment
    @test constructor_schema(CustomNetworkProtocol) === custom.constructor
    custom_virtual = protocol_schema(CustomVirtualEdgeProtocol)
    @test protocol_attachment(CustomVirtualEdgeProtocol) ===
          custom_virtual.attachment === EdgeAttachment
    @test permits_virtual_edge(CustomVirtualEdgeProtocol) ===
          custom_virtual.permits_virtual_edge === true
    @test protocol_attachment(CustomVirtualEdgeProtocol(1, 2)) ===
          EdgeAttachment
    @test permits_virtual_edge(CustomVirtualEdgeProtocol(1, 2))
    @test map(schema -> schema.constructor.constructor, protocol_schemas()) ==
          expected_protocols
    @test_throws ArgumentError protocol_attachment(InvalidNodeProtocol)
    @test_throws ArgumentError permits_virtual_edge(InvalidNodeProtocol)

    invalid_constructor = ConstructorSchema(
        InvalidNodeProtocol,
        "Invalid test metadata.",
        (
            ConstructorFieldSchema(
                :node,
                Int,
                "Incorrectly duplicated attachment.";
                required=true,
            ),
        ),
    )
    @test_throws ArgumentError ProtocolSchema(
        invalid_constructor,
        NodeAttachment,
        (ProtocolNodeRole(:node, OneNode, AttachmentBound),),
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(InvalidNodeProtocol, "Invalid test metadata."),
        EdgeAttachment,
        (ProtocolNodeRole(:node, OneNode, AttachmentBound),),
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(InvalidNodeProtocol, "Invalid test metadata."),
        NodeAttachment,
        (ProtocolNodeRole(:node, OneNode, AttachmentBound),),
        true,
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(InvalidNodeListProtocol, "Invalid node role type.", (
            ConstructorFieldSchema(
                :nodes,
                Int,
                "Incorrect scalar field.";
                required=true,
            ),
        )),
        NetworkAttachment,
        (ProtocolNodeRole(:nodes, ManyNodes, Configurable),),
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(
            MissingConfigurableRoleProtocol,
            "Missing configurable role field.",
        ),
        NetworkAttachment,
        (ProtocolNodeRole(:nodes, ManyNodes, Configurable),),
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(InvalidNodeProtocol, "Duplicate roles."),
        NetworkAttachment,
        (
            ProtocolNodeRole(:node, OneNode, Configurable),
            ProtocolNodeRole(:node, OneNode, Configurable),
        ),
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(InvalidNodeListProtocol, "Invalid attachment role."),
        NodeAttachment,
        (ProtocolNodeRole(:nodes, ManyNodes, AttachmentBound),),
    )

    @test !isdefined(QuantumSavory, :available_slot_types)
    @test !isdefined(QuantumSavory, :available_background_types)
    @test !isdefined(QuantumSavory, :constructor_metadata)
    @test !isdefined(
        QuantumSavory.ProtocolZoo,
        :available_protocol_types,
    )
    @test Base.get_extension(
        QuantumSavory,
        :QuantumSavoryInteractiveUtils,
    ) === nothing
    for legacy_name in (
        :ProtocolPlacement,
        :FloatingProtocolPlacement,
        :NodeProtocolPlacement,
        :EdgeProtocolPlacement,
        :protocol_placement,
    )
        @test !isdefined(QuantumSavory.ProtocolZoo, legacy_name)
    end
end
