using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

include("setup.jl")
using NetworkLayout

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}") 

function prepare_singlerun()
    n_rows  = 4
    n_cols  = 4
    n_nodes = n_rows * n_cols   
    regsize = 20               
    T2      = 100.0

    graph = grid([n_rows, n_cols])
    end_nodes = [1, n_cols, n_nodes - n_cols + 1, n_nodes]
    sim, net = simulation_setup(graph, regsize; T2=T2, end_nodes=end_nodes)

    flow1 = Flow(src=1, dst=n_cols, npairs=15, uuid=1)
    put!(net[1], flow1)
    flow2 = Flow(src=n_nodes - n_cols + 1, dst=n_nodes, npairs=15, uuid=2)
    put!(net[n_nodes - n_cols + 1], flow2)

    fig = Figure(;size=(1200, 800))
    
    layout = SquareGrid(cols=n_cols, dx=30.0, dy=-30.0)(graph)
    _, ax, _, obs = registernetplot_axis(fig[1,1:2], net; registercoords=layout)
    ax.title = "QTCP Routing on 4x4 Grid"

    # Track delivered pairs
    delivered_1 = Observable(0)
    delivered_2 = Observable(0)

    ax_bar = Axis(fig[2,1:2], xlabel="Flow", ylabel="Delivered Pairs", xticks=(1:2, ["Flow 1 (1->4)", "Flow 2 (13->16)"]))
    ylims!(ax_bar, (0, 15))
    barplot!(ax_bar, 1:2, @lift([$delivered_1, $delivered_2]), color=[:blue, :orange])

    return sim, net, obs, delivered_1, delivered_2, fig, flow1, flow2, n_nodes, n_cols
end

function continue_singlerun!(sim, net, obs, delivered_1, delivered_2, fig, flow1, flow2, n_nodes, n_cols, running)
    step_ts = range(0, 150, step=0.1)
    
    mb1 = messagebuffer(net, 1)
    mb13 = messagebuffer(net, n_nodes - n_cols + 1)

    function count_tags!(mb, tag_type)
        n = 0
        while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
            n += 1
        end
        return n
    end

    for t in step_ts
        run(sim, t)
        
        d1 = count_tags!(mb1, QTCPPairBegin)
        if d1 > 0
            delivered_1[] = delivered_1[] + d1
        end
        
        d2 = count_tags!(mb13, QTCPPairBegin)
        if d2 > 0
            delivered_2[] = delivered_2[] + d2
        end

        notify(obs)
    end
    running[] = nothing
end

landing = Bonito.App() do
    sim, net, obs, delivered_1, delivered_2, fig, flow1, flow2, n_nodes, n_cols = prepare_singlerun()

    running = Observable{Any}(false)
    fig[3,1] = buttongrid = GridLayout(tellwidth = false)
    buttongrid[1,1] = b = Makie.Button(fig, label = @lift(isnothing($running) ? "Done" : $running ? "Running..." : "Run simulation"), height=30, tellwidth=false)

    on(b.clicks) do _
        if !running[]
            running[] = true
        end
    end
    on(running) do r
        if r
            Threads.@spawn begin
                continue_singlerun!(
                    sim, net, obs, delivered_1, delivered_2, fig, flow1, flow2, n_nodes, n_cols, running)
            end
        end
    end

    content = md"""
    # QTCP Grid Routing Interactive Simulation
    
    Press 'Run simulation' to watch QTCP establish end-to-end entanglement on a 4x4 grid topology concurrently for two different flows.
    
    $(fig.scene)
    
    This example demonstrates how QTCP's connectionless design handles concurrent flows.
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_QTCP_PORT", "8895"))
interface = get(ENV, "QS_QTCP_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_QTCP_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

if abspath(PROGRAM_FILE) == @__FILE__
    wait(server)
end
