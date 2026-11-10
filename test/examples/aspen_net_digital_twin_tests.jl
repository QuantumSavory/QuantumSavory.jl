using Test
using HTTP, JSON3, Sockets, Random

include("../../examples/aspen_net/2_digital_twin.jl")

@testset "ASPEN-Net dashboard matches measurement periods" begin
    summary = AspenNetTwin.event_summary([], [], [])
    @test summary.success == summary.failure == zeros(Int, 2, 2)
    @test summary.counts == zeros(Int, 6)

    # Local rows may have different orders and missing periods; zero is a result.
    node1 = [(period=p, number=n) for (p, n) in ((2, 1), (1, 0), (3, 0), (5, 1), (8, 1))]
    node3 = [(period=p, number=n) for (p, n) in ((1, 1), (4, 0), (2, 0), (6, 1), (8, 1))]
    hub = [(period=p, success=s) for (p, s) in ((4, false), (2, false), (1, true), (3, true), (7, true))]
    summary = AspenNetTwin.event_summary(node1, node3, hub)
    @test summary.success == [0 1; 0 0] # Rows are node 1; columns are node 3.
    @test summary.failure == [0 0; 1 0]
    @test summary.counts == [2, 1, 1, 2, 2, 1]

    # A delayed hub result completes a pair and removes both pending records.
    push!(hub, (period=8, success=false))
    summary = AspenNetTwin.event_summary(node1, node3, hub)
    @test summary.failure == [0 0; 1 1]
    @test summary.counts == [3, 1, 1, 1, 1, 0]

    # Repeated outcomes contribute separately to the same heatmap cell.
    push!(node1, (period=9, number=0))
    push!(node3, (period=9, number=1))
    push!(hub, (period=9, success=true))
    @test AspenNetTwin.event_summary(node1, node3, hub).success == [0 2; 0 0]
end

@testset "ASPEN-Net configured setup and reset" begin
    config = AspenNetTwin.default_config()
    merge!(config[:network], Dict(:register_sizes => [3, 2, 2], :link_delay => 1.5))
    merge!(config[:protocol], Dict(:source_nodes => [2, 3], :hub_node => 1,
        :memories => [2], :hub_slots => [1, 3], :tick_duration => 0.5,
        :repetitions => 4, :heralding_probability => 1.0, :reflectivity => 0.25))
    merge!(config[:simulation], Dict(:reset_time => 12.0, :step_duration => 0.5,
        :initial_sleep_seconds => 0.25))
    twin = AspenNetTwin.prepare_twin(config)
    config[:network][:register_sizes][1] = 99
    config[:protocol][:source_nodes][1] = 1
    config[:simulation][:initial_sleep_seconds] = 99.0
    @test twin.config[:network][:register_sizes] == [3, 2, 2]
    @test twin.config[:protocol][:source_nodes] == [2, 3]
    state = twin.state[]
    @test [length(state.net[node]) for node in 1:3] == [3, 2, 2]
    @test AspenNetTwin.status_snapshot(twin) == (; time=0.0, tick_duration=0.5, repetitions=4)
    @test state.hub.node == 1 && state.hub.slots == (1, 3)
    @test all(source.reflectivity == 0.25 for source in state.sources)
    for source in state.sources
        put!(AspenNetTwin.messagebuffer(state.net, source.node), AspenNetTwin.Tag(AspenNetTwin.Start(0, 12)))
    end
    @test AspenNetTwin.advance!(twin) == 0.25
    @test AspenNetTwin.now(state.sim) == 0.5
    for _ in 1:15
        AspenNetTwin.advance!(twin)
    end
    for measurement in state.measurements
        @test [row.t for row in measurement._log] == [2.0, 4.0, 6.0]
        @test all(row.slot == 2 for row in measurement._log)
    end
    @test [row.t for row in state.hub._log] == [3.5, 5.5, 7.5]
    twin.sleep_seconds[] = 0.75
    AspenNetTwin.run(state.sim, 11.5)
    AspenNetTwin.advance!(twin)
    @test twin.state[].net !== state.net && AspenNetTwin.now(twin.state[].sim) == 0
    @test [source.node for source in twin.state[].sources] == [2, 3]
    @test [length(twin.state[].net[node]) for node in 1:3] == [3, 2, 2]
    @test all(isempty(measurement._log) for measurement in twin.state[].measurements)
    @test isempty(twin.state[].hub._log)
    @test twin.sleep_seconds[] == 0.75 && twin.config[:simulation][:initial_sleep_seconds] == 0.25
end

@testset "ASPEN-Net scenario API" begin
    config = AspenNetTwin.default_config()
    config[:network][:link_delay] = 0.25
    merge!(config[:protocol], Dict(:source_nodes => [2, 3], :hub_node => 1,
        :tick_duration => 0.5, :repetitions => 4, :heralding_probability => 1.0))
    config[:simulation][:reset_time] = 11.0 # Reset during a buffer period.
    twin = AspenNetTwin.prepare_twin(config)
    AspenNetTwin.configure_api(twin)
    request(path) = AspenNetTwin.internalrequest(HTTP.Request("POST", path))
    scenario = "/api/simulation/run_scenario?scenario=run_samples_until_reset"

    for path in ("/api/simulation/run_scenario?scenario=unknown&sleep_seconds=0",
            (scenario * "&sleep_seconds=$seconds" for seconds in (-1, NaN, Inf, "invalid"))...)
        @test request(path).status == 400
    end
    @test twin.sleep_seconds[] == 0.1
    @test all(iszero, values(twin.state[].last_stop))
    @test isempty(twin.state[].scheduled_periods)

    # A conflict on the second source must not start the first or change pacing.
    @test request("/api/nodes/3/start?start_tick=0&stop_tick=4").status == 202
    @test request(scenario * "&sleep_seconds=0").status == 409
    @test twin.sleep_seconds[] == 0.1
    AspenNetTwin.run(twin.state[].sim, 10.5)
    @test isempty(twin.state[].measurements[1]._log)
    @test length(twin.state[].measurements[2]._log) == 1
    @test AspenNetTwin.generation_attempts(twin.state[]) == 1
    AspenNetTwin.advance!(twin)

    # Exact boundaries start immediately; times between boundaries round up.
    for (time, start_tick, sleep_seconds) in ((0.0, 0, 0.0001), (0.5, 4, nothing), (2.0, 4, 0.0))
        state = twin.state[]
        AspenNetTwin.run(state.sim, time)
        previous_sleep = twin.sleep_seconds[]
        pacing = isnothing(sleep_seconds) ? "" : "&sleep_seconds=$sleep_seconds"
        response = request(scenario * pacing)
        @test response.status == 202
        accepted = JSON3.read(String(response.body))
        @test accepted.scenario == "run_samples_until_reset"
        @test accepted.nodes == [2, 3]
        @test accepted.start_tick == start_tick && accepted.stop_tick == 24
        @test accepted.sleep_seconds == twin.sleep_seconds[] ==
            something(sleep_seconds, previous_sleep)
        @test request(scenario * "&sleep_seconds=50").status == 409
        @test twin.sleep_seconds[] == accepted.sleep_seconds
        @test request("/api/nodes/2/start?start_tick=4&stop_tick=8").status == 409
        AspenNetTwin.run(state.sim, 10.5)
        releases = collect((start_tick * 0.5 + 2):2:10)
        @test all([row.t for row in measurement._log] == releases for measurement in state.measurements)
        @test [row.t for row in state.hub._log] == releases .+ 0.25
        @test AspenNetTwin.generation_attempts(state) == length(releases)
        AspenNetTwin.advance!(twin)
        @test twin.state[] !== state && AspenNetTwin.now(twin.state[].sim) == 0
        @test twin.sleep_seconds[] == accepted.sleep_seconds
        @test isempty(twin.state[].scheduled_periods)
        @test all(isempty(measurement._log) for measurement in twin.state[].measurements)
        @test isempty(twin.state[].hub._log)
    end
    # Reset leaves sources idle; a request too late to start changes nothing.
    AspenNetTwin.run(twin.state[].sim, 10.5)
    @test request(scenario * "&sleep_seconds=50").status == 409
    @test twin.sleep_seconds[] == 0
    @test all(iszero, values(twin.state[].last_stop))
    @test all(isempty(measurement._log) for measurement in twin.state[].measurements)
    @test isempty(twin.state[].hub._log)

    # Nonbinary periods can round time / period above an exact boundary.
    config[:protocol][:tick_duration] = 0.1
    config[:simulation][:reset_time] = 1.5
    twin = AspenNetTwin.prepare_twin(config)
    AspenNetTwin.configure_api(twin)
    boundary = 3 * (0.1 * 4)
    AspenNetTwin.run(twin.state[].sim, boundary)
    response = request(scenario)
    @test response.status == 202
    @test JSON3.read(String(response.body)).start_tick == 12
    AspenNetTwin.advance!(twin)
    AspenNetTwin.run(twin.state[].sim, nextfloat(boundary))
    @test request(scenario).status == 409 # The next boundary is after reset.
end

@testset "Examples - ASPEN-Net digital twin" begin
    Random.seed!(42)
    withenv("QS_ASPEN_NET_PORT" => "0", "QS_ASPEN_NET_PROXY" => "",
            "QS_ASPEN_NET_API_PORT" => "0", "QS_ASPEN_NET_API_PREFIX" => "/twin",
            "QS_ASPEN_NET_API_DOCPATH" => "/reference") do
        config = AspenNetTwin.default_config()
        config[:protocol][:reflectivity] = 0.25
        servers = AspenNetTwin.start_servers(AspenNetTwin.prepare_twin(config))
        twin = servers.twin
        api = "http://127.0.0.1:$(getsockname(servers.api.listener.server)[2])/twin"
        request(method, path) = HTTP.request(method, api * path; status_exception=false)
        data(path) = JSON3.read(String(request("GET", path).body))
        attempts() = lock(() -> AspenNetTwin.generation_attempts(twin.state[]), twin.guard)
        try
            initial_config = JSON3.read(JSON3.write(config))
            @test data("/api/simulation/config") == initial_config
            # The clock advances with no browser connected. Then pause it for exact checks.
            @test timedwait(() -> data("/api/status").time > 0, 30) == :ok
            @test data("/api/simulation/status").sleep_seconds == 0.1
            for seconds in (0, 0.02, 100)
                @test request("POST", "/api/simulation/pacing?sleep_seconds=$seconds").status == 200
                @test data("/api/simulation/status").sleep_seconds == seconds
            end
            for seconds in (-1, NaN, Inf)
                @test request("POST", "/api/simulation/pacing?sleep_seconds=$seconds").status == 400
            end
            paused_time = data("/api/status").time
            @test request("POST", "/api/simulation/pacing?sleep_seconds=0").status == 200
            @test timedwait(() -> data("/api/status").time > paused_time, 2) == :ok
            @test request("POST", "/api/simulation/pacing?sleep_seconds=100").status == 200
            @test data("/api/simulation/config") == initial_config
            # Shutdown interrupts even a long pacing delay.
            twin.stop[] = true
            @test timedwait(() -> istaskdone(servers.simulation), 2) == :ok
            wait(servers.simulation)
            @test isempty(data("/api/nodes/1/log"))
            @test isempty(data("/api/nodes/3/log"))
            status = data("/api/status")
            @test Set(keys(status)) == Set([:time, :tick_duration, :repetitions])
            @test Set(keys(data("/api/simulation/status"))) == Set([:sleep_seconds])
            period = status.tick_duration * status.repetitions
            lock(twin.guard) do
                AspenNetTwin.run(twin.state[].sim, status.time + 2 * period + 4.1)
            end
            @test isempty(data("/api/hub/log"))
            @test attempts() == 0 # Idle periods are not generation attempts.
            status = data("/api/status")
            start = (ceil(Int, status.time / period) + 1) * status.repetitions
            stop = start + 100 * status.repetitions
            interval = "?start_tick=$start&stop_tick=$stop"
            for node in (1, 3)
                @test request("POST", "/api/nodes/$node/start" * interval).status == 202
                @test request("POST", "/api/nodes/$node/start" * interval).status == 409
            end
            @test attempts() == 0 # Accepted future work has not completed a trial.
            @test request("POST", "/api/nodes/2/start" * interval).status == 400
            @test request("GET", "/api/nodes/2/log").status == 400
            @test request("POST", "/api/nodes/1/start?start_tick=1&stop_tick=40").status == 400
            @test request("POST", "/api/nodes/1/start?start_tick=0&stop_tick=40").status == 400
            @test request("GET", "/reference").status == 200
            schema = data("/reference/schema")
            @test haskey(schema.paths, "/twin/api/nodes/{node}/start")
            @test Set(p.name for p in schema.paths["/twin/api/nodes/{node}/start"].post.parameters) ==
                Set(["node", "start_tick", "stop_tick"])
            @test Set(keys(schema.paths["/twin/api/nodes/{node}/start"].post.responses)) ==
                Set([Symbol("202"), Symbol("400"), Symbol("409"), Symbol("500")])
            for (path, method) in (("/api/status", :get), ("/api/simulation/status", :get), ("/api/simulation/config", :get), ("/api/nodes/{node}/start", :post),
                    ("/api/nodes/{node}/log", :get), ("/api/hub/log", :get), ("/api/simulation/pacing", :post),
                    ("/api/simulation/run_scenario", :post))
                documentation = getproperty(schema.paths["/twin" * path], method)
                @test !isempty(documentation.summary) && !isempty(documentation.description)
            end
            pacing_docs = schema.paths["/twin/api/simulation/pacing"].post
            @test only(pacing_docs.parameters).name == "sleep_seconds"
            @test pacing_docs.tags == ["Simulation controls"]
            @test schema.paths["/twin/api/status"].get.tags == ["Network"]
            @test schema.paths["/twin/api/simulation/status"].get.tags == ["Simulation controls"]
            @test schema.paths["/twin/api/simulation/config"].get.tags == ["Simulation controls"]
            @test haskey(pacing_docs.responses, "400")
            scenario_docs = schema.paths["/twin/api/simulation/run_scenario"].post
            @test scenario_docs.tags == ["Simulation controls"]
            @test Dict(p.name => p.required for p in scenario_docs.parameters) ==
                Dict("scenario" => true, "sleep_seconds" => false)
            @test Set(keys(scenario_docs.responses)) == Set(Symbol.(("202", "400", "409", "500")))
            # Render the real Bonito handler, then observe the simulation through the HTTP API.
            ui_port = getsockname(servers.server.server.listener.server)[2]
            @test HTTP.get("http://127.0.0.1:$ui_port/").status == 200
            lock(twin.guard) do
                AspenNetTwin.run(twin.state[].sim, start * status.tick_duration + period - 0.1)
            end
            @test attempts() == 0
            lock(twin.guard) do
                AspenNetTwin.run(twin.state[].sim, start * status.tick_duration + period + 4.1)
            end
            @test attempts() == 1 # Two active sources share one buffered trial.
            lock(twin.guard) do
                AspenNetTwin.run(twin.state[].sim, stop * status.tick_duration + 4.1)
            end
            @test attempts() == 100 # Includes trials absent from measurement logs.
            hub_log = data("/api/hub/log")
            local_logs = [data("/api/nodes/$node/log") for node in (1, 3)]
            release_periods = sort!(unique([row.period for log in local_logs for row in log]))
            @test [row.period for row in hub_log] == release_periods
            @test any(row.success for row in hub_log)
            summary = AspenNetTwin.event_summary(local_logs[1], local_logs[2], hub_log)
            @test sum(summary.success) + sum(summary.failure) == summary.counts[1]
            @test sum(summary.counts[1:3]) == length(hub_log)
            @test summary.counts[4:6] == [0, 0, 0] # All arrivals have reached the hub.
            for log in local_logs
                @test !isempty(log)
                @test all(start * status.tick_duration < row.t <= stop * status.tick_duration && row.number in (0, 1) for row in log)
            end

            # Reset replaces the whole network, including accepted future work.
            after_reset = (ceil(Int, config[:simulation][:reset_time] / period) + 1) * status.repetitions
            @test request("POST", "/api/nodes/1/start?start_tick=$after_reset&stop_tick=$(after_reset + 2 * status.repetitions)").status == 202
            old_state = twin.state[]
            lock(twin.guard) do
                AspenNetTwin.run(old_state.sim, 99999)
            end
            @test attempts() == 100 # Idle gaps and work beyond reset do not count.
            AspenNetTwin.advance!(twin)
            @test attempts() == 0
            @test twin.state[].net !== old_state.net
            @test data("/api/status").time == 0
            @test data("/api/simulation/status").sleep_seconds == 100
            @test data("/api/simulation/config") == initial_config
            for path in ("/api/nodes/1/log", "/api/nodes/3/log", "/api/hub/log")
                @test isempty(data(path))
            end
            lock(twin.guard) do
                AspenNetTwin.run(twin.state[].sim, 100)
            end
            @test isempty(data("/api/hub/log"))
            start = (ceil(Int, 100 / period) + 1) * status.repetitions
            stop = start + 100 * status.repetitions
            @test request("POST", "/api/nodes/1/start?start_tick=$start&stop_tick=$stop").status == 202
            lock(twin.guard) do
                AspenNetTwin.run(twin.state[].sim, stop * status.tick_duration + 4.1)
            end
            @test !isempty(data("/api/nodes/1/log"))
            @test isempty(data("/api/nodes/3/log"))
            @test attempts() == 100 # One-sided source work also counts.
        finally
            AspenNetTwin.stop_servers(servers)
        end
        @test istaskdone(servers.simulation)
        @test !isopen(servers.api)
        @test !isopen(servers.server.server)
    end
end
