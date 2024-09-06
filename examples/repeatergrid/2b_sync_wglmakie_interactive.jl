using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown
# TODO significant code duplication with the other examples

include("setup.jl")

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}") # TODO remove after fix of bug in JSServe https://github.com/SimonDanisch/JSServe.jl/issues/178

function prepare_singlerun()
    # Prepare all of the simulation components (while all visualization components are prepared in the rest of this function)
    sim, net, graph, consumer, params... = prepare_simulation(;announce=false)

    # Prepare the main figure
    fig = Figure(;size=(1200, 1100))
    # the network part of the visualization
    layout = SquareGrid(cols=:auto, dx=30.0, dy=-30.0)(graph) # provided by NetworkLayout, meant to simplify plotting of graphs in 2D
    _, ax, _, obs = registernetplot_axis(fig[1:2,1], net;registercoords=layout)

    # the performance log part of the visualization
    entlog = Observable(consumer.log) # Observables are used by Makie to update the visualization in real-time in an automated reactive way
    ts = @lift [e[1] for e in $entlog]  # TODO this needs a better interface, something less cluncky, maybe also a whole Makie recipe
    tzzs = @lift [Point2f(e[1],e[2]) for e in $entlog]
    txxs = @lift [Point2f(e[1],e[3]) for e in $entlog]
    Δts = @lift length($ts)>1 ? $ts[2:end] .- $ts[1:end-1] : [0.0]
    entlogaxis = Axis(fig[1,2], xlabel="Time", ylabel="Entanglement", title="Entanglement Successes")
    ylims!(entlogaxis, (-1.04,1.04))
    stem!(entlogaxis, tzzs)
    histaxis = Axis(fig[2,2], xlabel="ΔTime", title="Histogram of Time to Successes")
    hist!(histaxis, Δts)

    avg_fids = @lift cumsum([e[3] for e in $entlog])./cumsum(ones(length($entlog))) #avg fidelity per unit time
    fid_info = @lift [Point2f(t,f) for (t,f) in zip($ts, $avg_fids)]
    fid_axis = Axis(fig[3,1], xlabel="Time", ylabel="Avg. Fidelity", title="Time evolution of Average Fidelity")
    lines!(fid_axis, fid_info)

    num_epr = @lift cumsum(ones(length($entlog)))./($ts) #avg number of pairs per unit time
    num_epr_info = @lift [Point2f(t,n) for (t,n) in zip($ts, $num_epr)]
    num_epr_axis = Axis(fig[3,2], xlabel="Time", title="Avg. Number of Entangled Pairs between Alice and Bob")
    lines!(num_epr_axis, num_epr_info)

    #  sliders
    sg = SliderGrid(
        fig[4,:],
        (label="Probability of success of Entanglement generation at each attempt",
            range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.001),
        (label="Local busy time for swapper",
            range=0.001:0.5:10.0, format="{:.3f}", startvalue=0.001),
        (label="Wait time after failure to lock qubits for a swap",
            range=0.1:0.05:1.0, format="{:.2f}", startvalue=0.1),
        (label="Retention time for an unused qubit",
            range=0.1:0.1:10.0, format="{:.2f}", startvalue=5.0),
        (label="Time before a qubit's retention time runs out (for `agelimit`)",
            range=0.1:0.5:10.0, format="{:.2f}", startvalue=0.5),
        (label="Period of time between subsequent queries at the consumer",
            range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.001),
        (label="Period of time between subsequent queries at the DecoherenceProtocol",
            range=0.001:0.05:1.0, format="{:.3f}", startvalue=0.001),

        width = 600,
        tellheight = false)

    for (param, slider) in zip(params, sg.sliders)
        on(slider.value) do val
            param[] = val
        end
    end

    return sim, net, obs, entlog, entlogaxis, histaxis, fig, params
end

# All the calls that happen in the main event loop of the simulation,
# encapsulated here so that we can conveniently pause the simulation from the WGLMakie app.
function continue_singlerun!(sim, obs, entlog, params, entlogaxis, histaxis, running)
    step_ts = range(0, 1000, step=0.1)
    for t in step_ts
        run(sim, t)
        notify.((obs,entlog))
        notify.(params)
        ylims!(entlogaxis, (-1.04,1.04))
        xlims!(entlogaxis, max(0,t-50), 1+t)
        ylims!(fid_axis, (0, 1.04))
        xlims!(fid_axis, max(0, t-50), 1+t)
        autolimits!(histaxis)
        ylims!(num_epr_axis, (0, 4))
        xlims!(num_epr_axis, max(0, t-50), 1+t)
    end
    running[] = nothing
end

#
landing = Bonito.App() do

    sim, net, obs, entlog, entlogaxis, histaxis, fig, params = prepare_singlerun()

    running = Observable{Any}(false)
    fig[4,1] = buttongrid = GridLayout(tellwidth = false)
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
                    sim, obs, entlog, params, entlogaxis, histaxis, running)
            end
        end
    end


    content = md"""
    Pick simulation settings and hit run (see below for technical details).

    $(fig.scene)

    # Simulations of Entanglement Distribution in a Grid with Synchronization

    The end nodes(Alice and Bob) are located on the diagonal corners of the grid.
    Each node runs control protocols like entanglement tracking and handling of outdated entangled pairs through decoherence protocol.
    Each horizontal and vertical edge between adjacent/neighboring nodes runs an entanglement generation protocol.
    All nodes except the end nodes run the swapper protocol to establish entanglement between Alice and Bob by extending the raw link level entanglement between each pair of nodes
    through a series of swaps until it reaches Alice and Bob.
    At the end nodes we run an entanglement consumer protocol which consumes the epr pair between them and logs the fidelity of the final epr pair along with the time it took to generate it.
    Both of these are presented in the top and bottom graphs on the right above respectively.

    All the classical information about the entanglement status of nodes after swaps is communicated through
    asynchronous messaging with the help of tags and queries and handled by the entanglement tracker. The decoherence protocol doesn't generate
    any messages here. Hence, the swapper protocol (`SwapperProt` with `agelimit`) checks every proposed candidate to be coherent before its used. Thus the swapper and decoherence protocol
    interact in a synchronous manner here.

   [See and modify the code for this simulation on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/repeatergrid/2b_sync_wglmakie_interactive.jl)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;

#
# Serve the Makie app

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_SYNC_REPEATERGRID_PORT", "8888"))
interface = get(ENV, "QS_SYNC_REPEATERGRID_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_SYNC_REPEATERGRID_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

##

wait(server)
