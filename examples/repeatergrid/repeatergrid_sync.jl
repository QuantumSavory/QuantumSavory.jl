using QuantumSavory

# For Simulation
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using Graphs

# For Plotting
using GLMakie
GLMakie.activate!()
using NetworkLayout

## Custom Predicates used for local decisions in the swapper protocol running at each node

"""A predicate function that checks if a remote node is in the appropriate quadrant with respect to the local node."""
function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end

"""A "cost" function for choosing the furthest node in the appropriate quadrant."""
function distance(n, a, b)
    x1 = a%n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b%n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n*(x1-1)
    y2 = b - n*(x2-1)
    return x1 - x2 + y1 - y2
end

"""A function that chooses the node in the appropriate quadrant that is furthest from the local node."""
function choose_node(net, node, arr; low=true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    return low ? argmax((distance.(grid_size, node, arr))) : argmin((distance.(grid_size, node, arr)))
end

## Simulation

n = 6 # the size of the square grid network (n × n)
regsize = 8 # the size of the quantum registers at each node

graph = grid([n,n])

net = RegisterNet(graph, [Register(regsize) for i in 1:n^2])

sim = get_time_tracker(net)

# each edge is capable of generating raw link-level entanglement
for (;src, dst) in edges(net)
    eprot = EntanglerProt(sim, net, src, dst; rounds=-1, randomize=true)
    @process eprot()
end

# each node except the corners on one of the diagonals is capable of swapping entanglement
for i in 2:(n^2 - 1)
    l(x) = check_nodes(net, i, x)
    h(x) = check_nodes(net, i, x; low=false)
    cL(arr) = choose_node(net, i, arr)
    cH(arr) = choose_node(net, i, arr; low=false)
    swapper = SwapperShedder(sim, net, i; nodeL = l, nodeH = h, chooseL = cL, chooseH = cH, rounds=-1)
    @process swapper()
end

# each node is running entanglement tracking to keep track of classical data about the entanglement
for v in vertices(net)
    tracker = EntanglementTracker(sim, net, v)
    @process tracker()
end

# a mock entanglement consumer between the two corners of the grid
consumer = EntanglementConsumer(sim, net, 1, n^2)
@process consumer()

# decoherence protocol runs at each node to free up slots that haven't been used past the retention time
for v in vertices(net)
    decprot = DecoherenceProt(sim, net, v; sync=true)
    @process decprot()
end

# By modifying the `period` of `EntanglementConsumer`, and `rate` of `EntanglerProt`, you can study the effect of different entanglement generation rates on the network

# Visualization

fig = Figure(;size=(600, 600))

# the network part of the visualization
layout = SquareGrid(cols=:auto, dx=10.0, dy=-10.0)(graph) # provided by NetworkLayout, meant to simplify plotting of graphs in 2D
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

display(fig)

step_ts = range(0, 200, step=0.1)
record(fig, "grid_sim6x6hv.mp4", step_ts; framerate=10, visible=true) do t
    run(sim, t)
    notify.((obs,entlog))
    ylims!(entlogaxis, (-1.04,1.04))
    xlims!(entlogaxis, max(0,t-50), 1+t)
    autolimits!(histaxis)
end
