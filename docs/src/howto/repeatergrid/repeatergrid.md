# [Entanglement Generation On A Repeater Grid](@id Entanglement-Generation-On-A-Repeater-Grid)

```@meta
DocTestSetup = quote
    using QuantumSavory
end
```

This section provides a detailed walkthrough of how the QuantumSavory.jl can be used to simulate entanglement generation on a network of repeaters.

We consider a square grid topology for the network. The registers act as repeater nodes with the ones on the diagonal corners acting as Alice and Bob respectively.

The goal is to establish entanglement between Alice and Bob by routing entanglement through any of the possible paths(horizontal or vertical) formed by local entanglement links and then swapping those links by performing bell state measurements(BSMs).

This employs functionality from the `ProtocolZoo` module of QuantumSavory to run the following Quantum Networking protocols:

- Entangler protocol to produce link level entanglement at each edge in the network

- Swapper protocol runs at each node except at Alice and Bob nodes, to perform BSMs and extend entanglement links by querying for 2 qubits, each entangled to a different neighbor in the desired direction

- Entanglement Tracker protocol to keep track of/and update the local link state knowledge by querying for Entanglement update messages generated after a BSM is performed by the Swapper protocol

All of the above protocols rely on the query and tagging functionality as described in the Tagging and Querying section in Expanations.

Other than that, `ConcurrentSim` and `ResumableFunctions` are used in the backend to run the discrete event simulation. `Graphs` helps with some functionality needed for `RegisterNet` datastructure that forms the grid. `GLMakie` and `NetworkLayout` are used for visualization along with the visualization functionality implemented in QuantumSavory.

# Custom Predicate And Choosing function

```julia
function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end
```
The Swapper Protocol is initialized with a custom predicate function which is then placed in a call to `queryall` inside the Swapper to pick the nodes that are suitable to perform a swap with. The criteria for 'suitability' is described in the further paragraphs.

The custom predicate function shown above is parametrized with `net` and `c_node` along with the keyword argument `low`, when initializing the Swapper Protocol. `node` remains a variable. This way, the Swapper protocol is passed a predicate function that maps `Int->Bool`.

Now, we describe the various arguments and their purpose:

- `net`: The network of registers/nodes representing the graph structure, implemented with the `RegisterNet` data structure.

- `c_node`: The node in which the Swapper protocol would be running.

- `node`: As the `queryall` function goes through all the nodes linked with the current node, those nodes are passed to the custom predicate as `node` which returns a `Bool` depending on whether the node is suitable for a swap or not.

- `low`: The nodes in the grid are numbered as consecutive integers starting from 1. If the Swapper is running at some node n, we want a link closest to Alice and another closest to Bob to perform a swap. We communicate whether we are looking for nodes of the first kind or the latter with the `low` keyword.

Out of all the links at some node, the suitable ones are picked by computing the difference between the coordinates of the current node with the coordinates of the candidate node. A `low` node should have both of the `x` and `y` coordinate difference positive and vice versa for a non-`low` node.

As the Swapper gets a list of suitable candidates for a swap in each direction, the one with the furthest distance from the current node is chosen by summing the x distance and y-distance.

```julia
function choose_node(net, node, arr; low=true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    return low ? argmax((distance.(grid_size, node, arr))) : argmin((distance.(grid_size, node, arr)))
end

function distance(n, a, b)
    x1 = a%n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b%n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n*(x1-1)
    y2 = b - n*(x2-1)

    return x1 - x2 + y1 - y2
end
```

# Simulation and Visualization

```julia
n = 6

graph = grid([n,n])

net = RegisterNet(graph, [Register(8) for i in 1:n^2])

sim = get_time_tracker(net)

for (;src, dst) in edges(net)
    eprot = EntanglerProt(sim, net, src, dst; rounds=5, randomize=true) # A single round doesn't always get the ends entangled, when number of nodes is high
    @process eprot()
end

for i in 2:(size(graph)[1] - 1)
    l(x) = check_nodes(net, i, x)
    h(x) = check_nodes(net, i, x; low=false)
    cL(arr) = choose_node(net, i, arr)
    cH(arr) = choose_node(net, i, arr; low=false)
    swapper = SwapperProt(sim, net, i; nodeL = l, nodeH = h, chooseL = cL, chooseH = cH, rounds = 5) # A single round doesn't always get the ends entangled, when number of nodes is high
    @process swapper()
end

for v in vertices(net)
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end
```

We set up the simulation to run with a 6x6 grid of nodes above. Here, each node has 8 qubit slots.
Each vertical and horizontal edge runs an entanglement generation protocol. Each node in the network runs an entanglement tracker protocol and all of the nodes except the nodes that we're trying to connect, i.e., Alice' and Bob's nodes which are at the diagonal ends of the grid run the swapper protocol. The code that runs and visualizes this simulation is shown below

```julia
layout = SquareGrid(cols=:auto, dx=10.0, dy=-10.0)(graph)
fig = Figure(resolution=(600, 600))
_, ax, _, obs = registernetplot_axis(fig[1,1], net;registercoords=layout)

display(fig)

step_ts = range(0, 10, step=0.1)
record(fig, "grid_sim6x6hv.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify(obs)
end
```

# Complete Code and Result

```@example grid
using QuantumSavory

# For Simulation
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using Graphs

# For Plotting
using GLMakie
GLMakie.activate!(inline=false)
using NetworkLayout

## Custom Predicates

function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end

# functions for picking the furthest node
function distance(n, a, b)
    x1 = a%n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b%n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n*(x1-1)
    y2 = b - n*(x2-1)

    return x1 - x2 + y1 - y2
end

function choose_node(net, node, arr; low=true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    return low ? argmax((distance.(grid_size, node, arr))) : argmin((distance.(grid_size, node, arr)))
end

## Simulation

n = 6

graph = grid([n,n])

net = RegisterNet(graph, [Register(8) for i in 1:n^2])

sim = get_time_tracker(net)

for (;src, dst) in edges(net)
    eprot = EntanglerProt(sim, net, src, dst; rounds=5, randomize=true) # A single round doesn't always get the ends entangled, when number of nodes is high
    @process eprot()
end

for i in 2:(size(graph)[1] - 1)
    l(x) = check_nodes(net, i, x)
    h(x) = check_nodes(net, i, x; low=false)
    cL(arr) = choose_node(net, i, arr)
    cH(arr) = choose_node(net, i, arr; low=false)
    swapper = SwapperProt(sim, net, i; nodeL = l, nodeH = h, chooseL = cL, chooseH = cH, rounds = 5) # A single round doesn't always get the ends entangled, when number of nodes is high
    @process swapper()
end

for v in vertices(net)
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

## Visualization
layout = SquareGrid(cols=:auto, dx=10.0, dy=-10.0)(graph)
fig = Figure(resolution=(600, 600))
_, ax, _, obs = registernetplot_axis(fig[1,1], net;registercoords=layout)

display(fig)

step_ts = range(0, 10, step=0.1)
record(fig, "grid_sim6x6hv.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify(obs)
end
```

