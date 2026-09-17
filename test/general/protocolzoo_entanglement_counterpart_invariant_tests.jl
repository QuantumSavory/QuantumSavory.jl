using Test
using Logging
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo:
    EntanglerProt,
    EntanglementCounterpart,
    EntanglementTracker,
    EntanglementUpdateX,
    SwapperProt

struct InvariantRecordLogger <: AbstractLogger
    records::Vector{Any}
end
Logging.min_enabled_level(::InvariantRecordLogger) = Logging.Error
Logging.shouldlog(::InvariantRecordLogger, args...) = true
Logging.catch_exceptions(::InvariantRecordLogger) = false
function Logging.handle_message(
    logger::InvariantRecordLogger, level, message, _module, group, id, file, line;
    kwargs...
)
    push!(logger.records, (; level, message, group, metadata=(; kwargs...)))
end

function capture_invariant_record(f)
    records = Any[]
    with_logger(f, InvariantRecordLogger(records))
    return only(filter(r -> get(r.metadata, :event, nothing) == :counterpart_tag_conflict, records))
end

@testset "EntanglerProt reports stale counterpart tags" begin
    net = RegisterNet([Register(1), Register(1)])
    sim = get_time_tracker(net)

    tag!(net[1][1], EntanglementCounterpart, 9, 1, 101)
    entangler = EntanglerProt(sim, net, 1, 2;
        success_prob = 1.0,
        attempts = 1,
        attempt_time = 0.0,
        rounds = 1,
    )

    record = capture_invariant_record() do
        @process entangler()
        run(sim, 0.1)
    end
    @test record.level == Logging.Error
    @test record.group == LOG_GROUPS.protocol
    @test record.metadata.protocol == :EntanglerProt
    @test record.metadata.nodes == (1, 2)
    @test record.metadata.slot == 1
end

@testset "EntanglementTracker reports leftover counterpart tags" begin
    net = RegisterNet([Register(1), Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    slot = net[1][1]

    initialize!(slot)
    tag!(slot, EntanglementCounterpart, 2, 1, 101)
    tag!(slot, EntanglementCounterpart, 4, 1, 404)
    put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, 101, 202, 2, 1, 1, 3, 1, 1))

    record = capture_invariant_record() do
        @process EntanglementTracker(sim, net, 1)()
        run(sim, 0.1)
    end
    @test record.group == LOG_GROUPS.protocol
    @test record.metadata.protocol == :EntanglementTracker
    @test record.metadata.nodes == (1,)
    @test record.metadata.slot == 1
end

@testset "SwapperProt reports same-slot counterpart tags" begin
    net = RegisterNet([Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    slot = net[2][1]

    initialize!(slot)
    tag!(slot, EntanglementCounterpart, 1, 1, 101)
    tag!(slot, EntanglementCounterpart, 3, 1, 202)

    swapper = SwapperProt(sim, net, 2;
        nodeL = <(2),
        nodeH = >(2),
        rounds = 1,
        retry_lock_time = 1.0,
    )

    record = capture_invariant_record() do
        @process swapper()
        run(sim, 0.1)
    end
    @test record.group == LOG_GROUPS.protocol
    @test record.metadata.protocol == :SwapperProt
    @test record.metadata.nodes == (2,)
    @test record.metadata.slot == 1
    @test record.metadata.remote_nodes == (1, 3)
    @test !islocked(slot)
end
