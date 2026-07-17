using Test
using Logging
using ConcurrentSim
using ResumableFunctions
using Graphs
using QuantumClifford: Stabilizer
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: AbstractProtocol
using QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation

struct LoggingFallbackProtocol <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
end

struct LoggingCustomProtocol <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
end

function QuantumSavory.ProtocolZoo.protocol_log_context(prot::LoggingCustomProtocol)
    return (
        simulation_log_context(prot.sim)...,
        protocol=:LoggingCustomProtocol,
        nodes=(prot.node,),
    )
end

struct RecordLogger <: AbstractLogger
    records::Vector{Any}
    groups::Set{Symbol}
end

Logging.min_enabled_level(::RecordLogger) = Logging.Debug
Logging.shouldlog(logger::RecordLogger, level, _module, group, id) =
    group in logger.groups
Logging.catch_exceptions(::RecordLogger) = false
function Logging.handle_message(
    logger::RecordLogger, level, message, _module, group, id, file, line;
    kwargs...
)
    push!(logger.records, (; level, message, group, metadata=(; kwargs...)))
end

function capture_records(f; groups=Set(values(LOG_GROUPS)))
    records = Any[]
    with_logger(f, RecordLogger(records, groups))
    return records
end

@testset "Structured logging contexts" begin
    @testset "public surface and removed helpers" begin
        @test :simulation_log_context in names(QuantumSavory)
        @test :protocol_log_context in names(QuantumSavory.ProtocolZoo)
        @test !isdefined(QuantumSavory, Symbol("@simlog"))
        @test !isdefined(QuantumSavory, :timestr)
    end

    @testset "simulation context order, types, and process id" begin
        sim = Simulation()
        outside = simulation_log_context(sim)
        @test propertynames(outside) == (:sim_time, :sim_process_id)
        @test outside.sim_time === 0.0
        @test outside.sim_time isa Float64
        @test outside.sim_process_id === nothing

        inside = Ref{Any}()
        active_id = Ref{UInt}()
        @resumable function capture_active_context(sim)
            active_id[] = active_process(sim).bev.id
            inside[] = simulation_log_context(sim)
        end

        @process capture_active_context(sim)
        run(sim)
        @test propertynames(inside[]) == (:sim_time, :sim_process_id)
        @test inside[].sim_time isa Float64
        @test inside[].sim_process_id isa UInt
        @test inside[].sim_process_id == active_id[]
    end

    @testset "protocol node mappings and snapshots" begin
        net = RegisterNet(
            star_graph(10),
            [Register(3) for _ in 1:10],
        )
        sim = get_time_tracker(net)

        entangler = EntanglerProt(sim, net, 2, 3)
        tracker = EntanglementTracker(sim, net, 4)
        consumer = EntanglementConsumer(sim, net, 5, 6)
        swapper = SwapperProt(sim, net, 7)
        cutoff = CutoffProt(sim, net, 8)
        switch = SimpleSwitchDiscreteProt(sim, net, 1, [2, 3], [1.0, 1.0])
        deleter = QuantumSavory.ProtocolZoo.Switches._SwitchSynchronizedDelete(switch)
        endnode = EndNodeController(sim, net, 4)
        networknode = NetworkNodeController(sim, net, 5)
        link = LinkController(sim, net, 6, 7)

        graph_nodes = [2, 3, 4]
        graph_constructor = GraphStateConstructor(
            sim, net, path_graph(3), graph_nodes, 1, 2
        )
        graph_resource = GraphToResource(
            sim, net, graph_nodes, 2, Int[], Int[], Int[]
        )
        measurements = PurifierBellMeasurements(
            sim, net, graph_nodes, 2, 5, 1, 2
        )
        empty_stabilizer = Stabilizer(falses(1, 2))
        purification_tracker = MBQCPurificationTracker(
            sim, net, graph_nodes, 1, 2, 5,
            zeros(Int, 0, 1), zeros(Int, 0, 1),
            empty_stabilizer, empty_stabilizer, 1, 2, false,
        )

        expected = [
            entangler => (2, 3),
            tracker => (4,),
            consumer => (5, 6),
            swapper => (7,),
            cutoff => (8,),
            switch => (1, 2, 3),
            endnode => (4,),
            networknode => (5,),
            link => (6, 7),
            graph_constructor => (2, 3, 4),
            graph_resource => (2, 3, 4),
            measurements => (2, 3, 4),
            purification_tracker => (2, 3, 4),
        ]

        for (prot, nodes) in expected
            context = protocol_log_context(prot)
            @test propertynames(context) ==
                (:sim_time, :sim_process_id, :protocol, :nodes)
            @test context.sim_time isa Float64
            @test context.sim_process_id === nothing
            @test context.protocol === nameof(typeof(prot))
            @test context.nodes === nodes
            @test context.nodes isa Tuple{Vararg{Int}}
            @test all(
                value isa Union{Float64,UInt,Nothing,Symbol,Tuple{Vararg{Int}}}
                for value in values(context)
            )
        end

        @test protocol_log_context(deleter) == protocol_log_context(switch)

        graph_context = protocol_log_context(graph_constructor)
        graph_nodes[1] = 10
        @test graph_context.nodes == (2, 3, 4)

        switch_context = protocol_log_context(switch)
        switch.clientnodes[1] = 4
        @test switch_context.nodes == (1, 2, 3)
    end

    @testset "custom fallback and overload" begin
        net = RegisterNet([Register(1)])
        sim = get_time_tracker(net)

        fallback = protocol_log_context(LoggingFallbackProtocol(sim, net))
        @test fallback == (
            sim_time=0.0,
            sim_process_id=nothing,
            protocol=:LoggingFallbackProtocol,
            nodes=(),
        )

        custom = protocol_log_context(LoggingCustomProtocol(sim, net, 1))
        @test custom == (
            sim_time=0.0,
            sim_process_id=nothing,
            protocol=:LoggingCustomProtocol,
            nodes=(1,),
        )
    end
end

@testset "Logging early filtering and evaluation" begin
    message_evaluations = Ref(0)
    context_evaluations = Ref(0)

    message() = (message_evaluations[] += 1; "Evaluated a message")
    context() = (context_evaluations[] += 1; (probe=1,))

    rejected = capture_records(groups=Set{Symbol}()) do
        @debug(
            message(),
            _group=LOG_GROUPS.protocol,
            event=:probe,
            context()...,
        )
    end
    @test isempty(rejected)
    @test message_evaluations[] == 0
    @test context_evaluations[] == 0

    accepted = capture_records(groups=Set([LOG_GROUPS.protocol])) do
        @debug(
            message(),
            _group=LOG_GROUPS.protocol,
            event=:probe,
            context()...,
        )
    end
    @test length(accepted) == 1
    @test message_evaluations[] == 1
    @test context_evaluations[] == 1
    @test accepted[1].metadata == (event=:probe, probe=1)
end

@testset "Representative structured records" begin
    @testset "deterministic entangler success" begin
        net = RegisterNet([Register(1), Register(1)])
        sim = get_time_tracker(net)
        prot = EntanglerProt(
            sim, net, 1, 2;
            success_prob=1.0,
            attempts=1,
            attempt_time=0.25,
            rounds=1,
        )

        records = capture_records() do
            @process prot()
            run(sim)
        end
        record = only(filter(r -> get(r.metadata, :event, nothing) == :pair_entangled, records))

        @test record.level == Logging.Debug
        @test record.message == "Entangled a pair"
        @test record.group == LOG_GROUPS.protocol
        @test record.metadata.sim_time == 0.25
        @test record.metadata.sim_process_id isa UInt
        @test record.metadata.protocol == :EntanglerProt
        @test record.metadata.nodes == (1, 2)
        @test record.metadata.round == 1
        @test record.metadata.slots == (1, 1)
        @test record.metadata.pair_id != 0
        @test record.metadata.attempts == 1
    end

    @testset "delayed MessageBuffer delivery" begin
        net = RegisterNet(
            [Register(1), Register(1)];
            classical_delay=2.5,
        )
        sim = get_time_tracker(net)
        put!(channel(net, 1=>2), Tag(:delayed_message))

        records = capture_records() do
            run(sim)
        end
        record = only(filter(
            r -> get(r.metadata, :event, nothing) == :message_received,
            records,
        ))

        @test record.level == Logging.Debug
        @test record.group == LOG_GROUPS.network
        @test record.metadata.sim_time == 2.5
        @test record.metadata.sim_process_id isa UInt
        @test record.metadata.component == :MessageBuffer
        @test record.metadata.src_node == 1
        @test record.metadata.dst_node == 2
        @test record.metadata.message_type == :delayed_message
    end
end
