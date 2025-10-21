# Live visualization of the piecemaker switch protocol
include("setup.jl")

using Base.Threads
using WGLMakie
WGLMakie.activate!()

using Bonito
using Markdown
const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}")

logging = Observable(Point2f[]) # for plotting

function push_to_logging!(logging::Observable, t::Float64, fidelity::Float64)
    push!(logging[], Point2f(t, fidelity))
end

function prepare_sim(fig::Figure, n::Int, link_success_prob::Float64, mem_depolar_prob::Float64)

    repr = QuantumOpticsRepr()

    decoherence_rate = -log(1 - mem_depolar_prob)
    noise_model = Depolarization(1 / decoherence_rate)

    switch  = Register([Qubit() for _ in 1:(n+1)], [repr for _ in 1:(n+1)], [noise_model for _ in 1:(n+1)])
    clients = [Register([Qubit()], [repr], [noise_model]) for _ in 1:n]

    graph = star_graph(n + 1)
    net   = RegisterNet(graph, [switch, clients...])
    sim   = get_time_tracker(net)
 
    # Attach the network plot to net and capture its obs
    _, ax_net, _, net_obs = registernetplot_axis(fig[1, 2], net)
    ax_net.title = "Network of n=5 users (live Δt = 0.1s)"
    # Fix the visible ranges
    xlims!(ax_net, -15, 15)
    ylims!(ax_net, -15, 15)
    ax_net.aspect = Makie.DataAspect()  # keep aspect ratio
    Makie.deregister_interaction!(ax_net, :scrollzoom) # disable zoom and pan interactions
    Makie.deregister_interaction!(ax_net, :dragpan)

    @process PiecemakerProt(sim, n, net, link_success_prob, -1) # set rounds=1

    return sim, net, net_obs
end

# A helper to add parameter sliders to visualizations
function add_conf_sliders(fig)
    conf = Dict(
        :link_success_prob => 0.5,
        :mem_depolar_prob => 0.1,
    )
    conf_obs = Observable(conf)
    sg = SliderGrid(
        fig,
        (label = "link success prob",
            range = 0.05:0.05:1.0, format = "{:.2f}", startvalue = conf[:link_success_prob]),
        (label = "mem depolar prob",
            range = 0.05:0.05:1.0, format = "{:.2f}", startvalue = conf[:mem_depolar_prob]),
        width = 300,
    )

    names = [:link_success_prob, :mem_depolar_prob]
    for (name,slider) in zip(names,sg.sliders)
        on(slider.value) do val
            conf_obs[][name] = val
        end
    end
    conf_obs
end

# Serve the Makie app
landing = Bonito.App() do

    n = 5  # number of clients

    fig = Figure(resolution = (800, 600))
    ax_fid = Axis(fig[1, 1], xlabel="Δt (time steps)", ylabel="Fidelity to GHZₙ", title="Fidelity")
    scatter!(ax_fid, logging, markersize = 8)
    ylims!(ax_fid, 0, 1.05)
    xlims!(ax_fid, 0, 30)

    running = Observable{Union{Bool,Nothing}}(false)
    fig[2, 1] = buttongrid = GridLayout(tellwidth = false)
    buttongrid[1,1] = b = Makie.Button(
        fig,
        label = @lift($running ? "Running..." : "Run once"),
        height = 30, tellwidth = false,
    )

    conf_obs = add_conf_sliders(fig[2, 2])

    on(b.clicks) do _
        if running[] # ignore while already running
            return
        end
        running[] = true
        @async begin
            try # run the sim
                sim, net, net_obs = prepare_sim(fig, n, conf_obs[][:link_success_prob], conf_obs[][:mem_depolar_prob])
                t = 0
                while true
                    t += 1
                    if length(logging[]) > 10
                        break
                    end
                    run(sim, t)
                    notify(net_obs)
                    notify(logging)
                    sleep(0.1)
                end
            finally
                running[] = false
                logging[] = Point2f[] # clear points for next run
            end
        end
    end

    content = md"""
    Pick simulation settings and hit “Run once”. The left panel plots the running fidelity to the target GHZ state; the right panel shows the network state as it evolves over 10 simulation rounds.

    $(fig.scene)

    # GHZ state distribution with a quantum entanglement switch

    This demo simulates 10 rounds of GHZ-state distribution in a star-shaped network with a central switch node and n client nodes. Each client holds one memory qubit locally and one at the switch. The switch has an extra “piecemaker” qubit (slot n+1) that is initialized in the |+⟩ state; it is used to fuse all successful links into an n-party GHZ state.

    What happens during one run:
    - Per time step, the switch attempts to entangle with each client in parallel (success probability set by the slider “link success prob”).
    - When a client<>switch entanglement attempt succeeds, the switch immediately fuses the client’s switch-side qubit with the piecemaker via a CNOT, measures the client qubit in Z, and sends the outcome to the client. The client applies necessary corrections.
    - After all clients have been fused, the piecemaker is measured in X. The first client receives that outcome and applies a Z correction if needed.
    - The current n-qubit state (the clients’ memory qubits) is compared to the ideal GHZₙ target state. The resulting fidelity is plotted as a point on the left over the number of taken time steps Δt.

    Noise model:
    - Memory qubits are subject to depolarizing noise ([`Depolarization`](https://qs.quantumsavory.org/stable/API/#QuantumSavory.Depolarization) background). The slider “mem depolar prob” controls the memory depolarization probability.

    UI guide:
    - Left: fidelity vs simulation time Δt. Points accumulate across runs so you can compare settings.
    - Right: network snapshot. Edges appear when links are established; updates every 0.1s of real time.
    - Sliders: tune link success probability and memory depolarization probability before each run.
    - Button: starts a single run with the current settings.

    NOTE that this is a simplified simulation for demonstration purposes. In particular, it assumes instantaneous gates as well as classical communication. The only time inducing steps are the attempts for heralded entanglement generation (Δt = 1 time step each).

    [Browse or modify the code for this simulation on GitHub.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/piecemakerswitch/live_visualization_interactive.jl)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;


isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_GHZSWITCH_PORT", "3000"))
interface = get(ENV, "QS_GHZSWITCH_IP", "0.0.0.0")  # Bind to all interfaces
proxy_url = get(ENV, "QS_GHZSWITCH_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);


@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

wait(server)