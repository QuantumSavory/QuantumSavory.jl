using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

include("setup.jl")

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}") # TODO remove after fix of bug in JSServe https://github.com/SimonDanisch/JSServe.jl/issues/178

phys_graph = PhysicalGraph(graph, 1, 8, regsize)
controller = Controller(sim, net, 6, phys_graph)
@process controller()

req_gen = RequestGenerator(sim, net, 1, 8, 6, phys_graph)
@process req_gen()

consumer = EntanglementConsumer(sim, net, 1, 8)
@process consumer()

for node in 1:7
    tracker = RequestTracker(sim, net, node)
    @process tracker()
end

for v in 1:8
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

for v in 1:8
    c_prot = CutoffProt(sim, net, v)
    @process c_prot()
end

# All the calls that happen in the main event loop of the simulation,
# encapsulated here so that we can conveniently pause the simulation from the WGLMakie app.
function continue_singlerun!(sim, obs, entlog, entlogaxis, fid_axis, histaxis, num_epr_axis, running)
    step_ts = range(0, 1000, step=0.1)
    for t in step_ts
        run(sim, t)
        notify.((obs,entlog)) 
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

    sim, net, obs, entlog, entlogaxis, fid_axis, histaxis, num_epr_axis, fig = prepare_vis(consumer)

    running = Observable{Any}(false)
    fig[5,1] = buttongrid = GridLayout(tellwidth = false)
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
                    sim, obs, entlog, entlogaxis, fid_axis, histaxis, num_epr_axis, running)
            end
        end
    end


    content = md"""
    Pick simulation settings and hit run (see below for technical details).

    $(fig.scene)

    # Connection-Oriented, Non-Distributed and Centralized Control Plane for Entanglement Distribution

    The above simulation visualizes entanglement distribution between Alice and Bob on an arbitrary network topology
    given by the adjacency matrix of the graph. The control plane architecture used for this simulation is connection-oriented,
    non-distributed and centralized. The node representing Alice is the node on the top left and the bottom right is Bob.
    The actual connectivity of the physical graph isn't fully captured by the visualization above as we use edges only to
    show the virtual graph.

   [See and modify the code for this simulation on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/controlplane/2b_cnc_wglmakie.jl)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;

#
# Serve the Makie app

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "CNC_PORT", "8888"))
interface = get(ENV, "CNC_IP", "127.0.0.1")
proxy_url = get(ENV, "CNC_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

##

wait(server)
