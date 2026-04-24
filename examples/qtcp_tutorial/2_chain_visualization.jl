# QTCP Tutorial — Script 2: Chain Visualization
#
# Same repeater chain as Script 1, but now with live Makie visualization
# showing how entanglement distribution progresses hop by hop.
#
# This script uses GLMakie to render the network state in real time,
# making it easy to see how QDatagrams traverse the chain and how
# Bell pairs are established at the endpoints.

include("setup.jl")
using GLMakie
GLMakie.activate!(inline=false)

# --- Network parameters ---
n_nodes = 5
regsize = 10
T2      = 100.0

graph = grid([n_nodes])
sim, net = simulation_setup(graph, regsize; T2=T2)

# Define a flow: 10 Bell pairs between end nodes
flow = Flow(src=1, dst=n_nodes, npairs=10, uuid=1)
put!(net[1], flow)

# --- Visualization setup ---
fig = Figure(size=(1000, 400))
_, ax, _, obs = registernetplot_axis(fig[1,1], net)
ax.title = "QTCP on a 5-node repeater chain"

display(fig)

# --- Run and animate ---
step_ts = range(0, 25, step=0.05)
output_path = get(ENV, "QSAVORY_QTCP_TUTORIAL_2_OUTPUT", "qtcp_chain.mp4")

# The `record` function runs the simulation in steps, updating the visualization at each step.
# It is provided by GLMakie and handles the animation recording.
record(fig, output_path, step_ts; framerate=30, visible=true) do t
    run(sim, t)
    ax.title = "t = $(round(t, digits=1))"
    notify(obs)
end

function count_delivered(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

mb_src = messagebuffer(net, 1)
mb_dst = messagebuffer(net, n_nodes)
n_delivered_src = count_delivered(mb_src, QTCPPairBegin)
n_delivered_dst = count_delivered(mb_dst, QTCPPairEnd)

@assert n_delivered_src == flow.npairs "Expected $(flow.npairs) pairs at source, got $n_delivered_src"
@assert n_delivered_dst == flow.npairs "Expected $(flow.npairs) pairs at destination, got $n_delivered_dst"
@assert isfile(output_path) "Expected visualization output $(output_path) to be created"

println("Animation saved to $(output_path)")
