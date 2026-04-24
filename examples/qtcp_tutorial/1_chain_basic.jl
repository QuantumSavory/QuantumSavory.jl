# QTCP Tutorial — Script 1: Basic Repeater Chain
#
# This script demonstrates the simplest QTCP setup: a linear repeater chain
# where two end users want to share Bell pairs. No custom code is needed —
# we use the out-of-the-box QTCP protocol suite.
#
# QTCP is a connectionless architecture: internal nodes maintain no per-user
# state. Entanglement swapping happens hop by hop, driven by QDatagrams that
# carry the logical state of a Bell-pair half across the network.
#
# In this example:
#   - 5 nodes in a chain: [1] — [2] — [3] — [4] — [5]
#   - Node 1 and Node 5 are the end users
#   - We request 10 Bell pairs via a single Flow

include("setup.jl")

# --- Network parameters ---
n_nodes = 5            # number of nodes in the chain
regsize = 10           # qubit slots per node
T2      = 100.0        # T2 dephasing time (seconds)

# Build a linear chain topology
graph = grid([n_nodes])

# Set up the simulation with the full QTCP protocol suite
sim, net = simulation_setup(graph, regsize; T2=T2)

# --- Define the application: a Flow ---
# A Flow is an intent: "node 1 and node 5 want to share 10 Bell pairs"
flow = Flow(src=1, dst=n_nodes, npairs=10, uuid=1)

# Inject the flow into the source node — the EndNodeController picks it up
put!(net[1], flow)

# --- Run the simulation ---
run(sim, 200.0)

# --- Check results ---
# At the source (node 1), successfully delivered pairs are tagged as QTCPPairBegin.
# At the destination (node 5), they are tagged as QTCPPairEnd.
mb_src = messagebuffer(net, 1)
mb_dst = messagebuffer(net, n_nodes)

function count_delivered(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

n_delivered_src = count_delivered(mb_src, QTCPPairBegin)
n_delivered_dst = count_delivered(mb_dst, QTCPPairEnd)

println("=== QTCP Chain Simulation Results ===")
println("Chain length:       $n_nodes nodes")
println("Requested pairs:    $(flow.npairs)")
println("Delivered at source: $n_delivered_src")
println("Delivered at dest:   $n_delivered_dst")
println("Simulation time:     $(round(now(sim), digits=2))")

@assert n_delivered_src == flow.npairs "Expected $(flow.npairs) pairs at source, got $n_delivered_src"
@assert n_delivered_dst == flow.npairs "Expected $(flow.npairs) pairs at destination, got $n_delivered_dst"
println("\nAll $(flow.npairs) Bell pairs successfully delivered!")
