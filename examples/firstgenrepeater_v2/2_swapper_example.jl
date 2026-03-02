include("setup.jl")

using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown
using Base.Threads
using Makie
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoMultiplexedCascadedBellPairW
using QuantumSavory.StatesZoo: stateparameters, stateparametersrange

@info "all library imports are complete"

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}")

function prepare_swapping_simulation(
    fig;
    config::Dict{Symbol,Any},
    state_config::Dict{Symbol,Float64},
)
    len = config[:len]
    regsize = config[:regsize]
    sizes = fill(regsize, len)

    sim, network = simulation_setup(sizes, config[:T2])

    pairstate = GenqoMultiplexedCascadedBellPairW(
        state_config[:ηᵇ],
        state_config[:ηᵈ],
        state_config[:ηᵗ],
        state_config[:N],
        state_config[:Pᵈ],
    )

    for (; src, dst) in edges(network)
        eprot = EntanglerProt(
            sim,
            network,
            src,
            dst;
            pairstate = pairstate,
            success_prob = config[:success_prob],
            attempt_time = config[:attempt_time],
            retry_lock_time = config[:retry_lock_time],
        )
        @process eprot()
    end

    for node in vertices(network)
        sprot = SwapperProt(
            sim,
            network,
            node;
            nodeL = <(node),
            nodeH = >(node),
            chooseL = argmin,
            chooseH = argmax,
            local_busy_time = config[:swapper_local_busy_time],
            retry_lock_time = config[:swapper_retry_lock_time],
        )
        @process sprot()
    end

    _, ax, _, obs = registernetplot_axis(fig[1, 1], network; interactions = false)

    return sim, network, obs, ax
end

function run_swapping_simulation!(sim, network, observables, axes, running; stop_time = 30.0)
    step_ts = range(0, stop_time, step = 0.1)
    for t in step_ts
        run(sim, t)
        notify.(observables)
        axes[1].title = "t=$(round(t; digits = 2))"
    end
    running[] = false
end

function state_summary(state_conf::Dict{Symbol,Float64}, order)
    join(
        ["$(string(key))=$(round(state_conf[key]; digits = 3))" for key in order],
        ", ",
    )
end

function add_configuration_controls(block)
    container = GridLayout(tellwidth = false)
    block[1, 1] = container

    config_defaults = Dict{Symbol,Any}(
        :len => 5,
        :regsize => 3,
        :T2 => 10.0,
        :success_prob => 0.05,
        :attempt_time => 0.002,
        :retry_lock_time => 0.1,
        :swapper_local_busy_time => 0.2,
        :swapper_retry_lock_time => 0.1,
        :stop_time => 30.0,
    )
    config_obs = Observable(copy(config_defaults))

    state_params = stateparameters(GenqoMultiplexedCascadedBellPairW)
    state_ranges = stateparametersrange(GenqoMultiplexedCascadedBellPairW)
    state_defaults = Dict{Symbol,Float64}(p => Float64(state_ranges[p].good) for p in state_params)
    state_obs = Observable(copy(state_defaults))

    config_section = container[1, 1] = GridLayout(tellwidth = false)
    config_section[1, 1] = Makie.Label("Simulation settings", textsize = 16, color = (:white, 0.85))

    sim_slider_grid = SliderGrid(
        config_section[2, 1],
        (label = "repeater count", range = 3:1:9, format = "{:d}", startvalue = config_defaults[:len]),
        (label = "register size", range = 2:1:6, format = "{:d}", startvalue = config_defaults[:regsize]),
        (label = "T₂", range = 1.0:1.0:100.0, format = "{:d}", startvalue = config_defaults[:T2]),
        (label = "success probability", range = 0.001:0.001:0.1, format = "{:.3f}", startvalue = config_defaults[:success_prob]),
        (label = "attempt time", range = 1e-4:1e-4:0.01, format = "{:.4f}", startvalue = config_defaults[:attempt_time]),
        (label = "entangler retry", range = 0.01:0.01:1.0, format = "{:.2f}", startvalue = config_defaults[:retry_lock_time]),
        (label = "swapper busy", range = 0.0:0.05:1.0, format = "{:.2f}", startvalue = config_defaults[:swapper_local_busy_time]),
        (label = "swapper retry", range = 0.01:0.01:1.0, format = "{:.2f}", startvalue = config_defaults[:swapper_retry_lock_time]),
        (label = "simulation horizon", range = 5.0:1.0:120.0, format = "{:d}", startvalue = config_defaults[:stop_time]),
        width = 520,
    )

    chain_label = config_section[3, 1] = Makie.Label(
        "chain: $(config_defaults[:len]) nodes × $(config_defaults[:regsize]) qubits",
        tellwidth = false,
        halign = :left,
    )

    function update_config!(name::Symbol, value)
        current = copy(config_obs[])
        if name in (:len, :regsize)
            current[name] = Int(round(value))
        else
            current[name] = Float64(value)
        end
        config_obs[] = current
        chain_label.text[] = "chain: $(current[:len]) nodes × $(current[:regsize]) qubits"
    end

    slider_names = (
        :len,
        :regsize,
        :T2,
        :success_prob,
        :attempt_time,
        :retry_lock_time,
        :swapper_local_busy_time,
        :swapper_retry_lock_time,
        :stop_time,
    )

    for (name, slider) in zip(slider_names, sim_slider_grid.sliders)
        on(slider.value) do val
            update_config!(name, val)
        end
    end

    state_section = container[2, 1] = GridLayout(tellwidth = false)
    state_section[1, 1] = Makie.Label("Genqo source parameters", textsize = 16, color = (:white, 0.85))

    state_slider_specs = [
        (
            label = string(param),
            range = LinRange(state_ranges[param].min, state_ranges[param].max, 101),
            format = "{:.4f}",
            startvalue = state_defaults[param],
        )
        for param in state_params
    ]
    state_slider_grid = SliderGrid(state_section[2, 1], state_slider_specs...; width = 520)

    state_label = state_section[3, 1] = Makie.Label(
        "state parameters: " * state_summary(state_defaults, state_params),
        tellwidth = false,
        halign = :left,
    )

    function update_state!(name::Symbol, value)
        range = state_ranges[name]
        clamped = clamp(Float64(value), range.min, range.max)
        current = copy(state_obs[])
        current[name] = clamped
        state_obs[] = current
        state_label.text[] = "state parameters: " * state_summary(current, state_params)
    end

    for (name, slider) in zip(state_params, state_slider_grid.sliders)
        on(slider.value) do val
            update_state!(name, val)
        end
    end

    return config_obs, state_obs
end

landing = Bonito.App() do
    fig = Figure(size = (900, 640))
    fig[1, 1] = controls = GridLayout(tellwidth = false)

    running = Observable(false)
    controls[1, 1] = button = Makie.Button(fig, label = @lift($running ? "Running..." : "Run simulation"))

    config_obs, state_obs = add_configuration_controls(controls[1, 2])

    on(button.clicks) do _
        if !running[]
            running[] = true
        end
    end

    on(running) do active
        if active
            config = deepcopy(config_obs[])
            state_config = deepcopy(state_obs[])

            fig[2, 1] = display_area = GridLayout()
            display_area[1, 1] = inner_fig = Figure(size = (640, 420))

            sim, network, obs, ax = prepare_swapping_simulation(
                inner_fig;
                config = config,
                state_config = state_config,
            )

            stop_time = Float64(config[:stop_time])

            Threads.@spawn begin
                try
                    run_swapping_simulation!(
                        sim,
                        network,
                        (obs,),
                        (ax,),
                        running;
                        stop_time = stop_time,
                    )
                catch err
                    @error "swapper simulation exited with error" err
                    running[] = false
                end
            end
        end
    end

    content = md"""
    Configure the repeater chain and the Genqo entanglement source, then run the simulation.

    $(fig.scene)

    # Entanglement Swapping with Genqo Sources

    This interactive demo runs the first-generation repeater chain while sourcing raw Bell pairs from the Genqo Multiplexed Cascaded model. Adjust both network parameters and state physics to see how the repeater behavior changes in real time.

    [View source for this example.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/firstgenrepeater_v2)
    """
    Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end

@info "app definition is complete"

isdefined(Main, :server) && close(server)
port = parse(Int, get(ENV, "QS_FIRSTGENREPEATER_V2_PORT", "8890"))
interface = get(ENV, "QS_FIRSTGENREPEATER_V2_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_FIRSTGENREPEATER_V2_PROXY", "")
server = Bonito.Server(interface, port; proxy_url)
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing)

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

wait(server)
