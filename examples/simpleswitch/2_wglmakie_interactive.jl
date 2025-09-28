using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

include("setup.jl")

@info "all library imports are complete"

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}") # TODO remove after fix of bug in JSServe https://github.com/SimonDanisch/JSServe.jl/issues/178

# Mostly a copy of the 1_interactive_visualization.jl file, encapsulated here for convenient serving from inside a WGLMakie app
function prepare_singlerun()
    # Prepare all of the simulation components (while all visualization components are prepared in the rest of this function)
    n, sim, net, switch_protocol, client_pairs, client_unordered_pairs, consumers, rates, rate_scale = prepare_simulation()

    # Prepare the main figure
    fig = Figure(size=(1600,800))
    fig_plots = fig[1,1]

    # Subfigure for the network visualization
    _,ax,_,obs = registernetplot_axis(fig_plots[1:2,1],net)

    # Subfigure for the "backlog over time"
    backlog = Observable(Float64[0])
    sim_time = Observable(Float64[0])
    ax_backlog = Axis(fig_plots[1:2,2], xlabel="time", ylabel="average backlog")
    stairs!(ax_backlog,sim_time,backlog)

    # Subfigure for the "total successfully established and consumed Bell pairs for a pair of clients"
    consumed = Observable(zeros(length(consumers)))
    ax_consumed_ticks = ["$i-$j" for (i,j) in client_unordered_pairs]
    ax_consumed = Axis(fig_plots[1,3], xlabel="pair", ylabel="consumed pairs", xticks=(1:length(consumers),ax_consumed_ticks))
    barplot!(ax_consumed,1:length(consumers),consumed, color=Cycled(2))

    # Subfigure for the "backlog for a given pair of clients"
    backlog_perpair = Observable(zeros(length(consumers)))
    ax_backlog_perpair = Axis(fig_plots[2,3], xlabel="pair", ylabel="backlog", xticks=(1:length(consumers),ax_consumed_ticks))
    barplot!(ax_backlog_perpair,1:length(consumers),backlog_perpair)

    # Sliders with which to control the request rates
    sliderfig_ = fig[2,1]
    sliderfig = sliderfig_[2,1]
    sliders = []
    for ((i,j), rate) in zip(client_pairs, rates)
        slider = Makie.Slider(sliderfig[i,j], range=0.05:0.05:2, startvalue=1)
        push!(sliders, slider)
        on(slider.value) do val
            rate[] = val*rate_scale
        end
    end
    for i in 1:n
        Label(sliderfig[1,i+1], "$(i+1)→", tellwidth=false)
        Label(sliderfig[i+1,1], "→$(i+1)", tellwidth=true)
    end
    sliderfig_override = sliderfig_[3,1]
    slider_override = Makie.Slider(sliderfig_override[1,2], range=0.05:0.05:2, startvalue=1)
    on(slider_override.value) do val
        for slider in sliders
            Threads.@spawn begin
                set_close_to!(slider, val)
            end
        end
    end
    Label(sliderfig_override[1,1], "global rate override:")
    Label(sliderfig_[1,1], rich("Request Rate Controls:",fontsize=20), tellwidth=false)

    axes = (;ax_backlog, ax_consumed, ax_backlog_perpair)
    observables = (;backlog, consumed, backlog_perpair, obs)

    return n, sim, net, switch_protocol, client_pairs, client_unordered_pairs, consumers, rates, rate_scale, sim_time, fig, observables, axes
end

# All the calls that happen in the main event loop of the simulation,
# encapsulated here so that we can conveniently pause the simulation from the WGLMakie app.
function continue_singlerun!(n, fig, sim, sim_time, switch_protocol, client_unordered_pairs, consumers,
    observables, axes, running
)
    backlog = observables._backlog
    consumed = observables.consumed
    backlog_perpair = observables.backlog_perpair
    step_ts = range(0, 1000, step=0.1)
    for t in step_ts
        run(sim, t)
        #ax.title = "t=$(t)"
        push!(sim_time[],t)
        push!(backlog[], sum(switch_protocol._backlog)/(n-1)/(n-2)/2)
        for (i, consumer) in enumerate(consumers)
            consumed[][i] = length(consumer._log)
        end
        for (l,(i, j)) in enumerate(client_unordered_pairs)
            backlog_perpair[][l] = switch_protocol._backlog[i-1,j-1]
        end
        notify.(tuple(observables...))
        autolimits!.(tuple(axes...))
    end
    running[] = nothing
end

#
landing = Bonito.App() do

    n, sim, net, switch_protocol, client_pairs, client_unordered_pairs, consumers, rates, rate_scale, sim_time, fig, observables, axes = prepare_singlerun()

    running = Observable{Any}(false)
    fig[3,1] = buttongrid = GridLayout(tellwidth = false)
    buttongrid[1,1] = b = Makie.Button(fig, label = @lift(isnothing($running) ? "Done" : $running ? "Running..." : "Run once"), height=30, tellwidth=false)

    on(b.clicks) do _
        if !running[]
            running[] = true
        end
    end
    on(running) do r
        if r
            Threads.@spawn begin
                continue_singlerun!(
                    n, fig, sim, sim_time, switch_protocol, client_unordered_pairs, consumers,
                    observables, axes, running)
            end
        end
    end


    content = md"""
    Pick simulation settings and hit run (see below for technical details).

    $(fig.scene)

    # Simulations of a simple entanglement switch

    The switch is in the center of a star network of clients.
    Each client can request to be connected to another client.
    The rate of requests can be configured for each pair through the sliders.

    After the switch successfully connects two clients, they share an entangled pair which is consumed shortly thereafter -- the total number of consumed pairs is tracked in one of the bar plots.

    The backlog of requests is tracked in the other set of plots.

    The switch runs one of the scheduling algorithms from "Maximizing Entanglement Rates via Efficient Memory Management in Flexible Quantum Switches" by Promponas et al (2024).

    [See and modify the code for this simulation on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/simpleswitch)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;

@info "app definition is complete"

#
# Serve the Makie app

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_SIMPLESWITCH_PORT", "8888"))
interface = get(ENV, "QS_SIMPLESWITCH_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_SIMPLESWITCH_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

##

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

wait(server)
