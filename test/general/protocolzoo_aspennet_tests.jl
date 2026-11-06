using Test, Random, Logging, InteractiveUtils, REPL
using ConcurrentSim, Graphs, QuantumSavory
using QuantumSavory.ProtocolZoo: protocol_log_context, available_protocol_types
using QuantumSavory.ProtocolZoo.AspenNet: Source, LocalMeasurement, Hub, Start, TimeTag, Confirmation

function aspen_setup(; probability=1.0, reflectivity=0.1, delay=0.25, tick=0.5, repetitions=2)
    net = RegisterNet(path_graph(3), [Register(2, QuantumOpticsRepr()) for _ in 1:3];
        classical_delay=delay, quantum_delay=delay)
    sources = [Source(net, node, 2; memories=[1, 2], tick_duration=tick, repetitions,
        heralding_probability=probability, reflectivity) for node in (1, 3)]
    measurements = [LocalMeasurement(net, node) for node in (1, 3)]
    hub = Hub(net, 2, (1, 3); tick_duration=tick, repetitions)
    return (; net, sim=get_time_tracker(net), sources, measurements, hub)
end

@testset "ASPEN-Net clocked optical model" begin
    Random.seed!(184)
    # Extremes distinguish vacuum, one local photon, and two-photon false heralds.
    for delay in (0.0, 0.25, 2.25), reverse_order in (false, true), (p, r) in ((0.0, 0.1), (1.0, 0.0), (1.0, 1.0))
        (; net, sim, sources, measurements, hub) = aspen_setup(; probability=p, reflectivity=r, delay)
        protocols = [sources; measurements; [hub]]
        foreach(Process, reverse_order ? reverse(protocols) : protocols)
        for node in (1, 3)
            put!(messagebuffer(net, node), Tag(Start(0, 8)))
        end
        run(sim, 4+2delay+0.01)
        @test all(log -> log.t == log.period+delay, hub._log)
        @test [log.success for log in hub._log if log.period <= 4] == fill(p*r == 1, 4)
        for measurement in measurements
            @test length(measurement._log) == (p == 0 ? 0 : 4)
            @test all(log -> log.t == log.period && log.number == 1-r, measurement._log)
            @test all(slot -> !isassigned(slot), net[measurement.node])
            @test isnothing(query(net[measurement.node], TimeTag, ❓))
            for log in hub._log
                log.t+delay > now(sim) && continue
                msg = querydelete!(messagebuffer(net, measurement.node), Confirmation, log.period, ❓)
                @test msg.tag[3] == Int(log.success)
            end
        end
        @test all(slot -> !isassigned(slot), net[2])
    end

    @testset "Probabilistic buffers conserve one photon per source" begin
        (; net, sim, sources, measurements, hub) = aspen_setup(; probability=0.2, reflectivity=0.3)
        foreach(Process, [sources; measurements; [hub]])
        for node in (1, 3)
            put!(messagebuffer(net, node), Tag(Start(0, 1000)))
        end
        run(sim, 500.6)
        for log in hub._log
            local_results = [result for m in measurements for result in m._log if result.period == log.period]
            remote_photons = sum((1-result.number for result in local_results); init=0)
            @test log.success == (remote_photons > 0)
        end
        @test all(m -> 120 < length(m._log) < 240, measurements)
        @test any(log -> log.success, hub._log) && any(log -> !log.success, hub._log)
    end

    @testset "Commands, memory selection, and classical arrival" begin
        (; net, sim, sources, measurements, hub) = aspen_setup(; reflectivity=1.0)
        initialize!(net[1][1], Z2) # Unrelated occupied memory must be left alone.
        foreach(Process, [sources; measurements; [hub]])
        run(sim, 1.1)
        @test all(m -> isempty(m._log), measurements)
        for command in (Start(-2, 8), Start(3, 8), Start(8, 4), Start(0, 8), Start(4, 8))
            put!(messagebuffer(net, 1), Tag(command))
        end
        run(sim, 3.3)
        @test only(measurements[1]._log).slot == 2
        @test only(measurements[1]._log).t == 3.0
        @test isempty(measurements[2]._log) # No command was sent to this source.
        @test last(hub._log).success # A missing source input is vacuum.
        @test isnothing(query(messagebuffer(net, 1), Confirmation, 3, ❓))
        run(sim, 4.6)
        @test query(messagebuffer(net, 1), Confirmation, 3, 1) !== nothing
        @test getproperty.(measurements[1]._log, :period) == [3, 4]
        @test isassigned(net[1][1])
        initialize!(net[1][2], Z2) # Full memories discard the next buffered photon.
        put!(messagebuffer(net, 1), Tag(Start(10, 12)))
        run(sim, 6.6)
        @test length(measurements[1]._log) == 2
        @test !last(hub._log).success
    end

    @testset "Adjacent commands share one floating-point clock grid" begin
        (; net, sim, sources, measurements, hub) = aspen_setup(; tick=0.1, repetitions=3, reflectivity=1.0)
        foreach(Process, [sources; measurements; [hub]])
        put!(messagebuffer(net, 1), Tag(Start(0, 18)))
        put!(messagebuffer(net, 1), Tag(Start(18, 36)))
        logger = Test.TestLogger(min_level=Logging.Debug)
        with_logger(logger) do
            run(sim, 4.2)
        end
        @test getproperty.(measurements[1]._log, :period) == 1:12
        records = filter(log -> log.group == LOG_GROUPS.protocol, logger.logs)
        @test any(log -> get(log.kwargs, :event, nothing) == :photon_released, records)
        @test all(log -> haskey(log.kwargs, :nodes), records)
    end

    @testset "Private protocol interfaces and validation" begin
        (; net, sim, sources, measurements, hub) = aspen_setup()
        for protocol in [sources; measurements; [hub]]
            @test get_time_tracker(protocol) === sim
            @test !isempty(protocol_log_context(protocol).nodes)
            @test !isempty(QuantumSavory.constructor_metadata(typeof(protocol)))
            @test all(entry -> entry.type !== typeof(protocol), available_protocol_types())
        end
        @test !Base.ispublic(QuantumSavory.ProtocolZoo, :AspenNet)
        @test_throws DomainError Source(net, 1, 2; heralding_probability=1.1)
        @test_throws DomainError Source(net, 1, 2; reflectivity=-0.1)
        @test_throws DomainError Source(net, 1, 2; repetitions=0)
        @test_throws DomainError Hub(net, 2, (1, 3); tick_duration=Inf)
        unequal = RegisterNet(path_graph(3), [Register(2) for _ in 1:3]; quantum_delay=1, classical_delay=2)
        @test_throws ArgumentError Source(unequal, 1, 2)
        @test_throws ArgumentError Hub(unequal, 2, (1, 3))
        @test_throws ArgumentError LocalMeasurement(; sim=Simulation(), net, node=1)
        for tag in (Start(0, 8), TimeTag(2), Confirmation(2, true))
            @test occursin("AspenNet", sprint(show, Tag(tag)))
        end
    end
end
