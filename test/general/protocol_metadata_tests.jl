using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo

struct CustomFloatingProtocol <: AbstractProtocol
    value::Int
end

QuantumSavory.ProtocolZoo.protocol_schema(::Type{CustomFloatingProtocol}) =
    ProtocolSchema(
        ConstructorSchema(
            CustomFloatingProtocol,
            "A test-only floating protocol.",
            (
                ConstructorFieldSchema(
                    :value,
                    Int,
                    "A test value.",
                ),
            ),
        ),
        FloatingProtocolPlacement,
        (),
    )

struct InvalidNodeProtocol <: AbstractProtocol
    node::Int
end

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
    )

    schemas = protocol_schemas()
    @test schemas isa Tuple
    @test map(schema -> schema.constructor.constructor, schemas) ==
          expected_protocols

    for schema in schemas
        protocol = schema.constructor.constructor
        @test protocol_schema(protocol) === schema
        @test constructor_schema(protocol) === schema.constructor
        @test protocol_placement(protocol) === schema.placement
        @test permits_virtual_edge(protocol) === schema.permits_virtual_edge
        @test !isempty(schema.constructor.doc)
        @test all(name -> name in fieldnames(protocol), schema.placement_fields)
        @test isempty(intersect(
            map(field -> field.name, schema.constructor.fields),
            (:sim, :net, schema.placement_fields..., :_log, :_backlog),
        ))

        for field in schema.constructor.fields
            @test field.declared_type === fieldtype(protocol, field.name)
            @test !isempty(field.doc)
        end
    end

    @test map(protocol_placement, expected_protocols) == (
        EdgeProtocolPlacement,
        NodeProtocolPlacement,
        NodeProtocolPlacement,
        EdgeProtocolPlacement,
        NodeProtocolPlacement,
        NodeProtocolPlacement,
        NodeProtocolPlacement,
        NodeProtocolPlacement,
        EdgeProtocolPlacement,
    )

    entangler = protocol_schema(EntanglerProt)
    @test entangler.placement_fields == (:nodeA, :nodeB)
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
    @test consumer.placement === EdgeProtocolPlacement
    @test consumer.placement_fields == (:nodeA, :nodeB)
    @test consumer.permits_virtual_edge
    @test count(schema -> schema.permits_virtual_edge, schemas) == 1

    switch_schema = protocol_schema(SimpleSwitchDiscreteProt)
    @test switch_schema.placement === NodeProtocolPlacement
    @test switch_schema.placement_fields == (:switchnode,)
    @test :clientnodes in map(
        field -> field.name,
        switch_schema.constructor.fields,
    )

    custom = protocol_schema(CustomFloatingProtocol)
    @test custom.constructor.constructor === CustomFloatingProtocol
    @test protocol_placement(CustomFloatingProtocol) ===
          FloatingProtocolPlacement
    @test constructor_schema(CustomFloatingProtocol) === custom.constructor
    @test map(schema -> schema.constructor.constructor, protocol_schemas()) ==
          expected_protocols

    invalid_constructor = ConstructorSchema(
        InvalidNodeProtocol,
        "Invalid test metadata.",
        (
            ConstructorFieldSchema(
                :node,
                Int,
                "Incorrectly duplicated placement.",
            ),
        ),
    )
    @test_throws ArgumentError ProtocolSchema(
        invalid_constructor,
        NodeProtocolPlacement,
        (:node,),
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(InvalidNodeProtocol, "Invalid test metadata."),
        EdgeProtocolPlacement,
        (:node,),
    )
    @test_throws ArgumentError ProtocolSchema(
        ConstructorSchema(InvalidNodeProtocol, "Invalid test metadata."),
        NodeProtocolPlacement,
        (:node,),
        true,
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
end
