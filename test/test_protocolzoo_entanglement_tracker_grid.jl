@testitem "ProtocolZoo Entanglement Tracker Grid" tags=[:protocolzoo_entanglement_tracker_grid] begin
using Test
using Revise
using ResumableFunctions
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ
using Graphs

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

##

# This set of tests ensures that the combination of entanglement genererator, tracker, and swapper works on what is basically a 1D chain of nodes that happen to be otherwise located in a grid.
# This set of tests DOES NOT test anything related to 2D grid structure of a network.
# It is little more than a copy of `test_entanglement_tracker` but with more complicated predicates for choosing who to swap in swapper protocol.

# Custom Predicates

#Choose any nodes that have a positive manhattan distance for "low nodes" and any nodes that have a negative manhattan distance for the "high nodes" case
function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end

# predicate for picking the furthest node
function distance(n, a, b)
    x1 = a%n == 0 ? a ÷ n : (a ÷ n) + 1
    x2 = b%n == 0 ? b ÷ n : (b ÷ n) + 1
    y1 = a - n*(x1-1)
    y2 = b - n*(x2-1)

    return x1 - x2 + y1 - y2
end

# filter for picking the furthest node
function choose_node(net, node, arr; low=true)
    grid_size = Int(sqrt(size(net.graph)[1]))
    return low ? argmax((distance.(grid_size, node, arr))) : argmin((distance.(grid_size, node, arr)))
end

##

# Here we run a bunch of low-level correctness tests for EntanglementProt and SwapperProt
# but we do not run a complete simulation that includes EntanglementTracker.
# Some arbitrary possible 1D chains embedded in the 2D grid
paths = [
    [2, 3, 4, 8, 12],
    [2, 6, 7, 11, 15],
    [5, 9, 13, 14, 15],
    [2, 6, 10, 14, 15],
    [5, 6, 7, 8, 12],
    [5, 6, 10, 11, 12],
    [2, 3, 7, 11, 12]
] # for 4x4 grid setup
for path in paths
    graph = grid([4, 4])

    net = RegisterNet(graph, [Register(3) for i in 1:16])
    sim = get_time_tracker(net)


    entangler1 = EntanglerProt(sim, net, 1, path[1]; rounds=1)
    @process entangler1()
    run(sim, 20)

    @test [net[1].tag_info[i].tag for i in net[1].guids] == [Tag(EntanglementCounterpart, path[1], 1)]


    # For no particular reason we are starting the entangler protocols at different times
    # and we run them for only one round
    entangler2 = EntanglerProt(sim, net, path[1], path[2]; rounds=1)
    @process entangler2()
    run(sim, 40)
    entangler3 = EntanglerProt(sim, net, path[2], path[3]; rounds=1)
    @process entangler3()
    run(sim, 60)
    entangler4 = EntanglerProt(sim, net, path[3], path[4]; rounds=1)
    @process entangler4()
    run(sim, 80)
    entangler5 = EntanglerProt(sim, net, path[4], path[5];rounds=1)
    @process entangler5()
    run(sim, 100)
    entangler6 = EntanglerProt(sim, net, path[5], 16; rounds=1)
    @process entangler6()
    run(sim, 120)

    @test [net[1].tag_info[i].tag for i in net[1].guids] == [Tag(EntanglementCounterpart, path[1], 1)]
    @test [net[path[1]].tag_info[i].tag for i in net[path[1]].guids] == [Tag(EntanglementCounterpart, 1, 1), Tag(EntanglementCounterpart, path[2], 1)]
    @test [net[path[2]].tag_info[i].tag for i in net[path[2]].guids] == [Tag(EntanglementCounterpart, path[1], 2), Tag(EntanglementCounterpart, path[3], 1)]
    @test [net[path[3]].tag_info[i].tag for i in net[path[3]].guids] == [Tag(EntanglementCounterpart, path[2], 2), Tag(EntanglementCounterpart, path[4], 1)]
    @test [net[path[4]].tag_info[i].tag for i in net[path[4]].guids] == [Tag(EntanglementCounterpart, path[3], 2), Tag(EntanglementCounterpart, path[5], 1)]
    @test [net[path[5]].tag_info[i].tag for i in net[path[5]].guids] == [Tag(EntanglementCounterpart, path[4], 2), Tag(EntanglementCounterpart, 16, 1)]
    @test [net[16].tag_info[i].tag for i in net[16].guids] == [Tag(EntanglementCounterpart, path[5], 2)]

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false

    for i in 1:5
        l = x->check_nodes(net, path[i], x)
        h = x->check_nodes(net, path[i], x; low=false)
        cL = arr->choose_node(net, path[i], arr)
        cH = arr->choose_node(net, path[i], arr; low=false)
        swapper = SwapperProt(sim, net, path[i]; nodeL=l, nodeH=h, chooseL=cL, chooseH=cH, rounds=1)
        @process swapper()
    end
    run(sim, 200)

    # In the absence of an entanglement tracker the tags will not all be updated
    @test [net[1].tag_info[i].tag for i in net[1].guids] == [Tag(EntanglementCounterpart, path[1], 1)]
    @test [net[path[1]].tag_info[i].tag for i in net[path[1]].guids] == [Tag(EntanglementHistory, 1, 1, path[2], 1, 2), Tag(EntanglementHistory, path[2], 1, 1, 1, 1)]
    @test [net[path[2]].tag_info[i].tag for i in net[path[2]].guids] == [Tag(EntanglementHistory, path[1], 2, path[3], 1, 2), Tag(EntanglementHistory, path[3], 1, path[1], 2, 1)]
    @test [net[path[3]].tag_info[i].tag for i in net[path[3]].guids] == [Tag(EntanglementHistory, path[2], 2, path[4], 1, 2), Tag(EntanglementHistory, path[4], 1, path[2], 2, 1)]
    @test [net[path[4]].tag_info[i].tag for i in net[path[4]].guids] == [Tag(EntanglementHistory, path[3], 2, path[5], 1, 2), Tag(EntanglementHistory, path[5], 1, path[3], 2, 1)]
    @test [net[path[5]].tag_info[i].tag for i in net[path[5]].guids] == [Tag(EntanglementHistory, path[4], 2, 16, 1, 2), Tag(EntanglementHistory, 16, 1, path[4], 2, 1)]
    @test [net[16].tag_info[i].tag for i in net[16].guids] == [Tag(EntanglementCounterpart, path[5], 2)]

    @test isassigned(net[1][1]) && isassigned(net[16][1])
    @test !isassigned(net[path[1]][1]) && !isassigned(net[path[2]][1])
    @test !isassigned(net[path[1]][2]) && !isassigned(net[path[2]][2])
    @test !isassigned(net[path[3]][1]) && !isassigned(net[path[4]][1])
    @test !isassigned(net[path[3]][2]) && !isassigned(net[path[4]][2])
    @test !isassigned(net[path[5]][1]) && !isassigned(net[path[5]][2])

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false
end

##

# Finally, we run the complete simulation, with EntanglerProt, SwapperProt, and EntanglementTracker,
# and we actually use a 2D grid of nodes.
# In these tests, we still use only a finite number of rounds.

# For this one, we have a square grid of nodes, and we add diagonal channels to the grid.
for n in 4:10
    graph = grid([n,n])

    for i in 1:(n^2 - n + 1) # add diagonal channels
        if !iszero(i%n) # no diagonal channel from last node in a row
            add_edge!(graph, i, i + n + 1)
        end
    end

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

    run(sim, 200)

    # has a small chance of failing due to the randomization of the entanglement protocols
    q1 = query(net[1], EntanglementCounterpart, size(graph)[1], ❓)
    q2 = query(net[size(graph)[1]], EntanglementCounterpart, 1, q1.slot.idx)

    @test q1.tag[2] == size(graph)[1]
    @test q2.tag[2] == 1
    @test observable((q1.slot, q2.slot), Z⊗Z) ≈ 1.0
    @test observable((q1.slot, q2.slot), X⊗X) ≈ 1.0
end

# and here we test for a simple 2d rectangular grid
for n in 4:7
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

    run(sim, 300)

    q1 = query(net[1], EntanglementCounterpart, size(graph)[1], ❓) # might return nothing in which case the next line fails -- solved by simulating for longer
    q2 = query(net[size(graph)[1]], EntanglementCounterpart, 1, q1.slot.idx)

    @test q1.tag[2] == size(graph)[1]
    @test q2.tag[2] == 1
    @test observable((q1.slot, q2.slot), Z⊗Z) ≈ 1.0
    @test observable((q1.slot, q2.slot), X⊗X) ≈ 1.0
end


##

# More tests of 2D rectangular grids with the full stack of protocols,
# but also now with an unlimited number of rounds and an entanglement consumer.


using Random; Random.seed!(12)
n = 5 # the size of the square grid network (n × n)
regsize = 20 # the size of the quantum registers at each node

graph = grid([n,n])
net = RegisterNet(graph, [Register(regsize) for i in 1:n^2], classical_delay=0.01)

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
    swapper = SwapperProt(sim, net, i; nodeL = l, nodeH = h, chooseL = cL, chooseH = cH, rounds=-1, agelimit=1.0)
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

# at each node we discard the qubits that have decohered after a certain cutoff time
for v in vertices(net)
    cutoffprot = CutoffProt(sim, net, v, retention_time=10, period=nothing)
    @process cutoffprot()
end
run(sim, 18.249)
run(sim, 400)

for i in 1:length(consumer._log)
    @test consumer._log[i][2] ≈ 1.0
    @test consumer._log[i][3] ≈ 1.0
end
end
