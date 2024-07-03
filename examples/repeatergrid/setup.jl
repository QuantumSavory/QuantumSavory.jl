using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using ConcurrentSim
using ResumableFunctions
using NetworkLayout

# Predicate function for swap decisions
"""A predicate function that checks if a remote node is in the appropriate quadrant with respect to the local node."""
function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end

#Choosing function to pick from swap candidates
"""A function that chooses the node in the appropriate quadrant that is furthest from the local node."""
function choose_node(net, node, arr; low=true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    return low ? argmax((distance.(grid_size, node, arr))) : argmin((distance.(grid_size, node, arr)))
end

"""A "cost" function for choosing the furthest node in the appropriate quadrant."""
function distance(n, a, b)
    x1 = a%n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b%n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n*(x1-1)
    y2 = b - n*(x2-1)
    return x1 - x2 + y1 - y2
end

# Simulation setup

function prepare_simulation(;sync=false)
    n = 6  # number of nodes on each row and column for a 6x6 grid
    regsize = 20 # memory slots in each node

    # The graph of network connectivity
    graph = grid([n,n])

    net = RegisterNet(graph, [Register(regsize) for i in 1:n^2])
    sim = get_time_tracker(net)

    ##Setup the networking protocols running between each of the nodes

    # Entanglement generation
    succ_prob = Observable(0.001)
    for (;src, dst) in edges(net)
        eprot = EntanglerProt(sim, net, src, dst; rounds=-1, randomize=true, success_prob=succ_prob[])
        @process eprot()
    end

    # Swapper
    local_busy_time = Observable(0.0)
    retry_lock_time = Observable(0.1)
    retention_time = Observable(5.0)
    buffer_time = Observable(0.5)

    for i in 2:(n^2 - 1)
        l(x) = check_nodes(net, i, x)
        h(x) = check_nodes(net, i, x; low=false)
        cL(arr) = choose_node(net, i, arr)
        cH(arr) = choose_node(net, i, arr; low=false)
        swapper = SwapperProt(
            sim, net, i;
            nodeL = l, nodeH = h,
            chooseL = cL, chooseH = cH,
            rounds=-1, local_busy_time=local_busy_time[],
            retry_lock_time=retry_lock_time[],
            agelimit=sync ? retention_time[]-buffer_time[] : nothing)
        @process swapper()
    end

    # Entanglement Tracking
    for v in vertices(net)
        tracker = EntanglementTracker(sim, net, v)
        @process tracker()
    end

    # Entanglement usage/consumption by the network end nodes
    period_cons = Observable(0.1)
    consumer = EntanglementConsumer(sim, net, 1, n^2; period=period_cons[])
    @process consumer()

    # decoherence protocol runs at each node to free up slots that haven't been used past the retention time
    period_dec = Observable(0.1)
    for v in vertices(net)
        decprot = CutoffProt(sim, net, v; sync=sync, period=period_dec[]) # TODO default and slider for retention_time
        @process decprot()
    end

    return sim, net, graph, consumer, succ_prob, local_busy_time, retry_lock_time, retention_time, buffer_time, period_cons, period_dec
end
