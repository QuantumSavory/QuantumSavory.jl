using Test
using Logging

struct LowLevelRecordLogger <: AbstractLogger
    records::Vector{Any}
end
Logging.min_enabled_level(::LowLevelRecordLogger) = Logging.Debug
Logging.shouldlog(::LowLevelRecordLogger, args...) = true
Logging.catch_exceptions(::LowLevelRecordLogger) = false
function Logging.handle_message(
    logger::LowLevelRecordLogger, level, message, _module, group, id, file, line;
    kwargs...
)
    push!(logger.records, (; level, message, group, metadata=(; kwargs...)))
end

@testset "Examples - firstgenrepeater_lowlevel 1" begin
    records = Any[]
    with_logger(LowLevelRecordLogger(records)) do
        include("../../examples/firstgenrepeater_lowlevel/1_entangler_example.jl")
    end

    pair_records = filter(
        record -> get(record.metadata, :event, nothing) == :pair_entangled &&
            get(record.metadata, :protocol, nothing) == :entangler,
        records,
    )
    @test !isempty(pair_records)
    record = first(pair_records)
    @test record.level == Logging.Debug
    @test record.group == LOG_GROUPS.protocol
    @test record.metadata.sim_time isa Float64
    @test record.metadata.sim_process_id isa UInt
    @test record.metadata.nodes isa NTuple{2,Int}
    @test record.metadata.slots isa NTuple{2,Int}
end
