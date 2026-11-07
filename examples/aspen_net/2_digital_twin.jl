module AspenNetTwin

using ConcurrentSim, Graphs, QuantumSavory
using QuantumSavory.ProtocolZoo.AspenNet: Source, LocalMeasurement, Hub, Start
using WGLMakie
import Bonito, Oxygen
using Oxygen: json
Oxygen.@oxidize

"""Startup settings for the two-source, one-hub digital twin; all values serialize to JSON."""
default_config() = Dict(
    :network => Dict(:register_sizes => [2, 2, 2], :link_delay => 2.0),
    :protocol => Dict(:source_nodes => [1, 3], :hub_node => 2,
        :memories => [1, 2], :hub_slots => [1, 2], :tick_duration => 1.0,
        :repetitions => 20, :heralding_probability => 0.1, :reflectivity => 0.1),
    :simulation => Dict(:reset_time => 100000.0, :step_duration => 1.0,
        :initial_sleep_seconds => 0.1))

function prepare_network(config)
    network, protocol = config[:network], config[:protocol]
    source_nodes, hub_node = protocol[:source_nodes], protocol[:hub_node]
    sizes = network[:register_sizes]
    length(source_nodes) == 2 && sort([source_nodes; hub_node]) == collect(eachindex(sizes)) ||
        throw(ArgumentError("Use two distinct source nodes and one hub covering all registers"))
    graph = SimpleGraph(length(sizes))
    foreach(node -> add_edge!(graph, node, hub_node), source_nodes)
    net = RegisterNet(graph, [Register(size, QuantumOpticsRepr()) for size in sizes];
        classical_delay=network[:link_delay], quantum_delay=network[:link_delay])
    sim = get_time_tracker(net)
    sources = [Source(net, node, hub_node; memories=copy(protocol[:memories]),
        tick_duration=protocol[:tick_duration], repetitions=protocol[:repetitions],
        heralding_probability=protocol[:heralding_probability], reflectivity=protocol[:reflectivity]) for node in source_nodes]
    measurements = [LocalMeasurement(net, node) for node in source_nodes]
    hub = Hub(net, hub_node, Tuple(source_nodes); slots=Tuple(protocol[:hub_slots]),
        tick_duration=protocol[:tick_duration], repetitions=protocol[:repetitions])
    protocols = (sources[1], measurements[1], hub, measurements[2], sources[2])
    foreach(Process, protocols)
    return (; sim, net, sources, measurements, hub, protocols,
        last_stop=Dict(node => 0 for node in source_nodes), scheduled_periods=Set{Int}())
end

function prepare_twin(config=default_config())
    config = deepcopy(config)
    simulation = config[:simulation]
    all(x -> isfinite(x) && x > 0, (simulation[:reset_time], simulation[:step_duration])) ||
        throw(ArgumentError("reset_time and step_duration must be finite and positive"))
    isfinite(simulation[:initial_sleep_seconds]) && simulation[:initial_sleep_seconds] >= 0 ||
        throw(ArgumentError("initial_sleep_seconds must be finite and nonnegative"))
    (; config, state=Ref(prepare_network(config)), sleep_seconds=Ref(Float64(simulation[:initial_sleep_seconds])),
        guard=ReentrantLock(), stop=Threads.Atomic{Bool}(false))
end

"""Advance one configured step, rebuilding the network at the configured reset time."""
function advance!(twin)
    lock(twin.guard) do
        state = twin.state[]
        simulation = twin.config[:simulation]
        run(state.sim, min(now(state.sim) + simulation[:step_duration], simulation[:reset_time]))
        now(state.sim) >= simulation[:reset_time] && (twin.state[] = prepare_network(twin.config))
        twin.sleep_seconds[]
    end
end

function status_snapshot(twin)
    lock(twin.guard) do
        state = twin.state[]
        source = first(state.sources)
        (; time=now(state.sim), source.tick_duration, source.repetitions)
    end
end

function simulation_status_snapshot(twin)
    lock(twin.guard) do
        (; sleep_seconds=twin.sleep_seconds[])
    end
end

"""Count completed scheduled buffer periods, including empty outcomes; caller holds the guard."""
function generation_attempts(state)
    source = first(state.sources)
    duration = source.tick_duration * source.repetitions
    count(period -> period * duration <= now(state.sim), state.scheduled_periods)
end

"""Match measurements by period; callers hold the guard when reading live logs."""
function event_summary(node1_log, node3_log, hub_log)
    node1 = Dict(row.period => row.number for row in node1_log)
    node3 = Dict(row.period => row.number for row in node3_log)
    hub_periods = Set(row.period for row in hub_log)
    success, failure = zeros(Int, 2, 2), zeros(Int, 2, 2)
    counts = zeros(Int, 6)
    for row in hub_log
        in1, in3 = haskey(node1, row.period), haskey(node3, row.period)
        if in1 && in3
            counts[1] += 1
            (row.success ? success : failure)[node1[row.period] + 1, node3[row.period] + 1] += 1
        elseif in1
            counts[2] += 1
        elseif in3
            counts[3] += 1
        end
    end
    # Both source records count here while their hub result is still pending.
    counts[4] = count(period -> period ∉ hub_periods, keys(node1))
    counts[5] = count(period -> period ∉ hub_periods, keys(node3))
    counts[6] = count(period -> haskey(node3, period) && period ∉ hub_periods, keys(node1))
    return (; success, failure, counts)
end

function configure_api(twin)
    source_nodes = twin.config[:protocol][:source_nodes]
    node_choices = join(source_nodes, " or ")
    @get "/api/status" function(req)
        status_snapshot(twin)
    end
    @get "/api/simulation/status" function(req)
        simulation_status_snapshot(twin)
    end
    @get "/api/simulation/config" function(req)
        lock(twin.guard) do
            deepcopy(twin.config)
        end
    end
    @post "/api/simulation/pacing" function(req, sleep_seconds::Float64)
        isfinite(sleep_seconds) && sleep_seconds >= 0 ||
            return json((; error="sleep_seconds must be finite and nonnegative"); status=400)
        lock(twin.guard) do
            twin.sleep_seconds[] = sleep_seconds
        end
        (; sleep_seconds)
    end
    @post "/api/nodes/{node}/start" function(req, node::Int, start_tick::Int, stop_tick::Int)
        node in source_nodes || return json((; error="End node must be $node_choices"); status=400)
        lock(twin.guard) do
            state = twin.state[]
            source = first(state.sources)
            period = source.tick_duration * source.repetitions
            if !(0 <= start_tick < stop_tick) ||
                    start_tick % source.repetitions != 0 || stop_tick % source.repetitions != 0 ||
                    (start_tick ÷ source.repetitions) * period < now(state.sim)
                return json((; error="Use a future interval with ticks divisible by $(source.repetitions)"); status=400)
            end
            start_tick < state.last_stop[node] &&
                return json((; error="Interval overlaps an earlier command"); status=409)
            put!(messagebuffer(state.net, node), Tag(Start(start_tick, stop_tick)))
            state.last_stop[node] = stop_tick
            # One shared trial per active buffer period; work after reset never runs.
            last_period = min(stop_tick ÷ source.repetitions, floor(Int, twin.config[:simulation][:reset_time] / period))
            union!(state.scheduled_periods, (start_tick ÷ source.repetitions + 1):last_period)
            json((; node, start_tick, stop_tick); status=202)
        end
    end
    @get "/api/nodes/{node}/log" function(req, node::Int)
        index = findfirst(==(node), source_nodes)
        isnothing(index) && return json((; error="End node must be $node_choices"); status=400)
        lock(twin.guard) do
            copy(twin.state[].measurements[index]._log)
        end
    end
    @get "/api/hub/log" function(req)
        lock(twin.guard) do
            copy(twin.state[].hub._log)
        end
    end
    # Oxygen merges this prose into the generated parameter schemas and Swagger UI.
    for (method, path, summary, description, responses) in (
        ("get", "/api/status", "Read hardware clock status",
            "Returns the modeled hardware's shared clock time, tick_duration, and repetitions per buffer, used to schedule source work.",
            (200 => "Hardware status",)),
        ("get", "/api/simulation/status", "Read simulation status",
            "Returns sleep_seconds: the wall-clock pacing delay between simulation steps. This setting is specific to the digital twin.",
            (200 => "Simulation status",)),
        ("get", "/api/simulation/config", "Read the simulation configuration",
            "Returns the startup dictionary used to build and reset this twin: network register sizes and link delay; source/hub roles, memories, timing and optical settings; reset time, step duration and initial pacing. Current pacing is reported by /api/simulation/status.",
            (200 => "Simulation configuration",)),
        ("post", "/api/nodes/{node}/start", "Schedule an end node",
            "node is $node_choices. start_tick and stop_tick delimit an increasing future interval and must be multiples of repetitions. Work remaining at the configured reset time is discarded.",
            (202 => "Accepted interval", 400 => "Invalid numeric interval or node ID", 409 => "Overlap with earlier work")),
        ("get", "/api/nodes/{node}/log", "Read local number measurements",
            "Returns node $node_choices's current-run history: period, t (release time), slot, and number (0 or 1). Histories clear on reset.",
            (200 => "Local measurement history", 400 => "Node ID must be $node_choices")),
        ("get", "/api/hub/log", "Read hub outcomes",
            "Returns current-run entries with period, t (arrival time), and success. A period is recorded only if at least one mode arrived; an arriving vacuum can produce failure. Histories clear on reset.",
            (200 => "Hub measurement history",)),
        ("post", "/api/simulation/pacing", "Set simulation pacing (not a hardware control)",
            "Set sleep_seconds to a finite nonnegative wall-clock delay after each configured simulation step. Zero removes deliberate pacing. Changes interrupt the previous delay and persist across resets. Pacing is approximate.",
            (200 => "Selected sleep_seconds", 400 => "Negative or nonfinite sleep_seconds")))
        group = startswith(path, "/api/simulation/") ? "Simulation controls" : "Network"
        mergeschema(path, Dict(method => Dict("summary" => summary,
            "description" => description, "tags" => [group])))
        operation = getschema()["paths"][path][method]
        operation["responses"] = Dict(string(code) => Dict("description" => text) for (code, text) in responses)
        operation["responses"]["500"] = Dict("description" => "Missing or unparseable parameters, or an internal server error")
    end
end

function dashboard(twin, session)
    lock(twin.guard) do
        state = twin.state[]
        node1, node3 = twin.config[:protocol][:source_nodes]
        fig = Figure(size=(1800, 1050))
        status = Observable(status_snapshot(twin))
        simulation_status = Observable(simulation_status_snapshot(twin))
        status_text = lift(status, simulation_status) do hardware, simulation
            "ASPEN-Net — Hardware: time $(hardware.time); tick_duration $(hardware.tick_duration); repetitions $(hardware.repetitions)\nSimulation: sleep_seconds $(simulation.sleep_seconds)"
        end
        Label(fig[0, 1:5], status_text)
        # Disable live-state inspection: network reads happen only under the guard.
        coords = Vector{Point2f}(undef, length(state.net.registers))
        coords[[node1, state.hub.node, node3]] = Point2f[(0, 0), (5, 0), (10, 0)]
        _, _, _, network = registernetplot_axis(fig[1, 1:5], state.net;
            registercoords=coords, infocli=false, datainspector=false)
        plots = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
        histories, axes = Observable[], Axis[]
        for (column, protocol) in enumerate(state.protocols)
            panel = GridLayout(fig[2, column])
            Label(panel[0, 1], "$(nameof(typeof(protocol))) · node $(protocol.node)"; tellwidth=false)
            if protocol isa Source
                plots.protshowimage(panel, protocol)
            else
                history = Observable(protocol._log)
                push!(histories, history)
                push!(axes, plots.protshowimage(panel, protocol; history))
            end
        end
        summary = Observable(event_summary(state.measurements[1]._log, state.measurements[2]._log, state.hub._log))
        attempts = Observable(generation_attempts(state))
        outcomes = GridLayout(fig[3, 1:5])
        colorrange = lift(summary -> (0, max(1, maximum(summary.success), maximum(summary.failure))), summary)
        for (column, outcome) in enumerate((:success, :failure))
            counts = lift(summary -> getproperty(summary, outcome), summary)
            title = lift(counts, attempts) do counts, total
                "Hub $outcome ($(sum(counts)) events)\nout of $total total generation attempts"
            end
            panel = GridLayout(outcomes[1, column])
            axis = Axis(panel[1, 1]; title, xlabel="Node $node1 photon number",
                ylabel="Node $node3 photon number", xticks=0:1, yticks=0:1)
            heatmap = heatmap!(axis, 0:1, 0:1, counts; colorrange)
            Colorbar(panel[1, 2], heatmap; label="Events")
            limits!(axis, -0.5, 1.5, -0.5, 1.5)
        end
        counts_title = lift(total -> "Coincidence counts\nout of $total total generation attempts", attempts)
        counts_axis = Axis(outcomes[1, 3]; title=counts_title, ylabel="Events",
            xticks=(1:6, ["All three", "Node $node1\n+ hub only", "Node $node3\n+ hub only",
                "Node $node1\nwithout hub", "Node $node3\nwithout hub", "Both nodes\nwithout hub"]))
        barplot!(counts_axis, 1:6, lift(summary -> summary.counts, summary))
        xlims!(counts_axis, 0.5, 6.5)
        ylims!(counts_axis, 0, max(1, 1.1 * maximum(summary[].counts)))
        # WGLMakie's frame timer belongs to this browser session; refresh twice a second.
        last_refresh = Ref(0.0)
        Bonito.on(session, events(fig).tick) do tick
            tick.time - last_refresh[] >= 0.5 || return
            last_refresh[] = tick.time
            lock(twin.guard) do
                state = twin.state[]
                network[] = state.net
                for (history, protocol) in zip(histories, (state.measurements[1], state.hub, state.measurements[2]))
                    history[] = protocol._log
                end
                for axis in axes
                    autolimits!(axis)
                    ylims!(axis, -0.2, 1.2)
                end
                status[] = status_snapshot(twin)
                simulation_status[] = simulation_status_snapshot(twin)
                summary[] = event_summary(state.measurements[1]._log, state.measurements[2]._log, state.hub._log)
                attempts[] = generation_attempts(state)
                ylims!(counts_axis, 0, max(1, 1.1 * maximum(summary[].counts)))
            end
        end
        Bonito.DOM.div(fig)
    end
end

function start_servers(twin=prepare_twin())
    Threads.nthreads(:default) >= 2 && Threads.nthreads(:interactive) == 1 ||
        error("Launch with julia --threads=2,1 --project=examples examples/aspen_net/2_digital_twin.jl")
    WGLMakie.activate!(framerate=10)
    configure_api(twin)
    server = nothing
    try
        api = serve(; async=true, metrics=false,
            host=Base.get(ENV, "QS_ASPEN_NET_API_IP", "127.0.0.1"),
            port=parse(Int, Base.get(ENV, "QS_ASPEN_NET_API_PORT", "8081")),
            external_url=Base.get(ENV, "QS_ASPEN_NET_API_PROXY", nothing),
            prefix=Base.get(ENV, "QS_ASPEN_NET_API_PREFIX", nothing),
            docs_path=Base.get(ENV, "QS_ASPEN_NET_API_DOCPATH", "/docs"))
        server = Bonito.Server(Base.get(ENV, "QS_ASPEN_NET_IP", "127.0.0.1"),
            parse(Int, Base.get(ENV, "QS_ASPEN_NET_PORT", "8897"));
            proxy_url=Base.get(ENV, "QS_ASPEN_NET_PROXY", ""))
        Bonito.route!(server, "/" => Bonito.App(session -> dashboard(twin, session)))
        simulation = errormonitor(Threads.@spawn :default begin
            while !twin.stop[]
                seconds = advance!(twin)
                # Pacing is approximate; even a long delay must allow prompt shutdown.
                if seconds == 0
                    yield()
                else
                    timedwait(seconds; pollint=clamp(seconds, 0.001, 0.1)) do
                        twin.stop[] || lock(() -> twin.sleep_seconds[] != seconds, twin.guard)
                    end
                end
            end
        end)
        return (; twin, server, api, simulation)
    catch
        isnothing(server) || close(server)
        terminate()
        rethrow()
    end
end

function stop_servers(servers)
    servers.twin.stop[] = true
    try
        close(servers.server)
    finally
        try
            terminate()
        finally
            wait(servers.simulation)
        end
    end
end

function main()
    servers = start_servers()
    try
        wait(servers.simulation)
    finally
        stop_servers(servers)
    end
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    AspenNetTwin.main()
end
