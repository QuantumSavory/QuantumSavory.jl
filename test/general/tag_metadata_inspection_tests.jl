using Test
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo

struct CustomInspectionTag <: AbstractTag
    label::Symbol
    count::Int
end

QuantumSavory.Tag(tag::CustomInspectionTag) =
    Tag(CustomInspectionTag, tag.label, tag.count)

QuantumSavory.tag_head_schema(::Type{CustomInspectionTag}) = TagHeadSchema(
    CustomInspectionTag,
    "A test-only named tag.",
    (
        TagFieldSchema(:label, Symbol, "A label."),
        TagFieldSchema(:count, Int, "A count."),
    ),
)

_sample_tag_value(::Type{Int}) = 1
_sample_tag_value(::Type{Float64}) = 1.5
_sample_tag_value(::Type{Symbol}) = :value

@testset "Tag metadata and inspection" begin
    expected_heads = (
        EntanglementCounterpart,
        EntanglementHistory,
        EntanglementUpdateX,
        EntanglementUpdateZ,
        QuantumSavory.ProtocolZoo.EntanglementDelete,
        SwitchRequest,
        Flow,
        QTCPPairBegin,
        QTCPPairEnd,
        QDatagram,
        QuantumSavory.ProtocolZoo.QTCP.QDatagramSuccess,
        LinkLevelRequest,
        LinkLevelReply,
        LinkLevelReplyAtSource,
        LinkLevelReplyAtHop,
        QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation.GraphStateStorage,
        QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation.PurifierBellMeasurementResults,
        QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation.PurifiedEntanglementCounterpart,
    )

    schemas = tag_head_schemas()
    @test schemas isa Tuple
    @test map(schema -> schema.head, schemas) == expected_heads
    @test length(unique(expected_heads)) == length(expected_heads)

    for schema in schemas
        @test tag_head_schema(schema.head) === schema
        @test !isempty(schema.doc)
        @test map(field -> field.name, schema.fields) ==
              fieldnames(schema.head)
        @test map(field -> field.declared_type, schema.fields) ==
              fieldtypes(schema.head)
        @test all(field -> !isempty(field.doc), schema.fields)

        values = map(
            field -> _sample_tag_value(field.declared_type),
            schema.fields,
        )
        named_value = schema.head(values...)
        tag = Tag(named_value)
        parts = tag_parts(tag)
        @test parts.head === schema.head
        @test parts.fields == values
    end

    expected_signatures = (
        (Symbol, ()),
        (Symbol, (Int,)),
        (Symbol, (Int, Int)),
        (Symbol, (Int, Int, Int)),
        (Symbol, (Int, Int, Int, Int)),
        (Symbol, (Int, Int, Int, Int, Int)),
        (Symbol, (Int, Int, Int, Int, Int, Int)),
        (Symbol, (Float64,)),
        (Symbol, (Float64, Float64)),
        (DataType, ()),
        (DataType, (Int,)),
        (DataType, (Int, Int)),
        (DataType, (Int, Int, Int)),
        (DataType, (Int, Int, Int, Int)),
        (DataType, (Int, Int, Int, Int, Int)),
        (DataType, (Int, Int, Int, Int, Int, Int)),
        (DataType, (Int, Int, Int, Int, Int, Int, Int)),
        (DataType, (Int, Int, Int, Int, Int, Int, Int, Int)),
        (DataType, (Int, Float64)),
        (DataType, (Int, Int, Float64)),
        (DataType, (Int, Int, Int, Float64)),
        (DataType, (Int, Int, Int, Int, Float64)),
        (DataType, (Int, Int, Int, Int, Int, Float64)),
        (DataType, (Symbol,)),
        (DataType, (Symbol, Int)),
        (DataType, (Symbol, Int, Int)),
    )
    signatures = general_tag_signatures()
    @test signatures isa Tuple
    @test map(
        signature -> (signature.head_type, signature.field_types),
        signatures,
    ) == expected_signatures

    for signature in signatures
        head = signature.head_type === Symbol ? :generic : Int
        fields = map(_sample_tag_value, signature.field_types)
        tag = Tag(head, fields...)
        parts = tag_parts(tag)
        @test parts.head === head
        @test parts.fields == fields
    end

    custom = tag_head_schema(CustomInspectionTag)
    @test custom.head === CustomInspectionTag
    @test tag_parts(Tag(CustomInspectionTag(:custom, 2))) ==
          TagParts(CustomInspectionTag, (:custom, 2))
    @test map(schema -> schema.head, tag_head_schemas()) == expected_heads

    @test_throws ArgumentError TagHeadSchema(
        CustomInspectionTag,
        "Incomplete.",
        (TagFieldSchema(:label, Symbol, "A label."),),
    )
    @test_throws ArgumentError TagSignatureSchema(Int, ())

    symbolic_parts = tag_parts(Tag(:ready, 3, 4))
    @test symbolic_parts ===
          TagParts(:ready, (3, 4))
    @test isimmutable(symbolic_parts)

    register = Register(2)
    first_id = tag!(register[2], :first, 1)
    second_id = tag!(register[1], :second, 2)
    third_id = tag!(register[2], :third, 3)

    records = tag_records(register)
    @test records isa Vector{TagRecord}
    @test map(record -> record.id, records) ==
          [first_id, second_id, third_id]
    @test map(record -> record.slot, records) == [2, 1, 2]
    @test map(record -> record.tag, records) == [
        Tag(:first, 1),
        Tag(:second, 2),
        Tag(:third, 3),
    ]
    @test all(record -> record.time == 0.0, records)
    @test tag_records(register[2]) == records[[1, 3]]
    @test all(isimmutable, records)

    untag!(register, first_id)
    @test map(record -> record.id, tag_records(register)) ==
          [second_id, third_id]
    @test map(record -> record.id, records) ==
          [first_id, second_id, third_id]

    network = RegisterNet([Register(1), Register(1)])
    simulation = get_time_tracker(network)
    buffer = messagebuffer(network, 2)
    put!(buffer, Tag(:local))
    put!(channel(network, 1 => 2), Tag(:remote, 7))
    run(simulation)

    messages = message_records(buffer)
    @test messages isa Vector{MessageRecord}
    @test map(message -> message.source, messages) == [nothing, 1]
    @test map(message -> message.tag, messages) ==
          [Tag(:local), Tag(:remote, 7)]
    @test length(unique(map(message -> message.id, messages))) == 2
    @test all(isimmutable, messages)

    querydelete!(buffer, :local)
    @test map(message -> message.tag, message_records(buffer)) ==
          [Tag(:remote, 7)]
    @test map(message -> message.tag, messages) ==
          [Tag(:local), Tag(:remote, 7)]

    timed_register = Register(2)
    initialize!(timed_register[1]; time=2.5)
    @test access_time(timed_register[1]) === 2.5
    @test access_time(timed_register[2]) === 0.0
    @test access_time(timed_register[1]) isa Float64
end
