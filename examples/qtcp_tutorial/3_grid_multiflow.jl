# QTCP Tutorial — Script 3: Grid Topology with Multiple Flows
#
# This script shows how QTCP scales to richer topologies with concurrent users.
# We change just a couple of lines from the chain example: replace the chain
# graph with a grid, and add multiple Flows for different user pairs.
#
# QTCP's connectionless design means internal nodes need no per-user state.
# The same protocol suite works on any topology — the only difference is
# the graph passed to `simulation_setup`.

include("setup.jl")

# --- Network parameters ---
n_rows  = 4
n_cols  = 4
n_nodes = n_rows * n_cols   # 16-node grid
regsize = 20               # more slots to handle concurrent flows
T2      = 100.0

# Build a grid topology — this is the ONLY line that changes from the chain!
graph = grid([n_rows, n_cols])

# Set up the simulation with the full QTCP protocol suite.
# End nodes are at the four corners of the grid.
end_nodes = [1, n_cols, n_nodes - n_cols + 1, n_nodes]
sim, net = simulation_setup(graph, regsize; T2=T2, end_nodes=end_nodes)

# --- Define multiple concurrent Flows ---
# Flow 1: bottom-left (1) → top-right (n_cols)
flow1 = Flow(src=1, dst=n_cols, npairs=5, uuid=1)
put!(net[1], flow1)

# Flow 2: top-left (n_nodes - n_cols + 1) → bottom-right (n_nodes)
flow2 = Flow(src=n_nodes - n_cols + 1, dst=n_nodes, npairs=5, uuid=2)
put!(net[n_nodes - n_cols + 1], flow2)

# --- Run simulation ---
run(sim, 300.0)

# --- Verify results ---
function count_tags(mb, tag_type)
    n = 0
    while !isnothing(querydelete!(mb, tag_type, ❓, ❓, ❓, ❓, ❓, ❓))
        n += 1
    end
    return n
end

mb1   = messagebuffer(net, 1)
mb4   = messagebuffer(net, n_cols)
mb13  = messagebuffer(net, n_nodes - n_cols + 1)
mb16  = messagebuffer(net, n_nodes)

flow1_src = count_tags(mb1, QTCPPairBegin)
flow1_dst = count_tags(mb4, QTCPPairEnd)
flow2_src = count_tags(mb13, QTCPPairBegin)
flow2_dst = count_tags(mb16, QTCPPairEnd)

println("\n=== Flow 1: node 1 → node $(n_cols) ===")
println("QTCPPairBegin at src: $flow1_src")
println("QTCPPairEnd at dst:   $flow1_dst")

println("\n=== Flow 2: node $(n_nodes-n_cols+1) → node $(n_nodes) ===")
println("QTCPPairBegin at src: $flow2_src")
println("QTCPPairEnd at dst:   $flow2_dst")

@assert flow1_src == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 source, got $flow1_src"
@assert flow1_dst == flow1.npairs "Expected $(flow1.npairs) pairs at flow 1 destination, got $flow1_dst"
@assert flow2_src == flow2.npairs "Expected $(flow2.npairs) pairs at flow 2 source, got $flow2_src"
@assert flow2_dst == flow2.npairs "Expected $(flow2.npairs) pairs at flow 2 destination, got $flow2_dst"
