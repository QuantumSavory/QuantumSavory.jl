using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

include("setup.jl")


const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}") # TODO remove after fix of bug in JSServe https://github.com/SimonDanisch/JSServe.jl/issues/178

succ_prob = Observable(0.001)
for (;src, dst) in edges(net)
    eprot = EntanglerProt(sim, net, src, dst; rounds=-1, randomize=true, success_prob=succ_prob[])
    @process eprot()
end

local_busy_time = Observable(0.0)
retry_lock_time = Observable(0.1)
for node in 2:7
    swapper = SwapperProt(sim, net, node; nodeL = <(node), nodeH = >(node), chooseL = argmin, chooseH = argmax, rounds=-1, local_busy_time=local_busy_time[],
    retry_lock_time=retry_lock_time[])
    @process swapper()
end

for v in vertices(net)
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

period_cons = Observable(0.1)
consumer = EntanglementConsumer(sim, net, 1, 8; period=period_cons[])
@process consumer()

period_dec = Observable(0.1)
for v in vertices(net)
    cutoff = CutoffProt(sim, net, v; period=period_dec[])
    @process cutoff()
end
params = [succ_prob, local_busy_time, retry_lock_time, period_cons, period_dec]

# All the calls that happen in the main event loop of the simulation,
# encapsulated here so that we can conveniently pause the simulation from the WGLMakie app.
function continue_singlerun!(sim, obs, entlog, params, entlogaxis, fid_axis, histaxis, num_epr_axis, running)
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

    sim, net, obs, entlog, entlogaxis, fid_axis, histaxis, num_epr_axis, fig = prepare_vis(consumer, params)

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
                    sim, obs, entlog, params, entlogaxis, fid_axis, histaxis, num_epr_axis, running)
            end
        end
    end


    content = md"""
    Pick simulation settings and hit run (see below for technical details).

    $(fig.scene)

    # Connectionless, Distributed and Decentralized Control Plane for Entanglement Distribution

    The above simulation visualizes entanglement distribution between Alice and Bob on an arbitrary network topology
    given by the adjacency matrix of the graph. The control plane architecture used for this simulation is connectionless,
    distributed and decentralized. The node representing Alice is the node on the top left and the bottom right is Bob.
    The actual connectivity of the physical graph isn't fully captured by the visualization above as we use edges only to
    show the virtual graph.

   [See and modify the code for this simulation on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/controlplane/1b_cdd_wglmakie.jl)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;

#
# Serve the Makie app

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "CDD_PORT", "8888"))
interface = get(ENV, "CDD_IP", "127.0.0.1")
proxy_url = get(ENV, "CDD_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

##

wait(server)