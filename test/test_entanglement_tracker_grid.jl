using Revise
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ
using Graphs
using Test

##
# Here we test entanglement tracker and swapper protocols on an arbitrary hardcoded path of long-range connection inside of what is otherwise a 2D grid
# We do NOT test anything related to automatic routing on such a grid -- only the hardcoded path is tested
##

## Custom Predicates

function check_nodes(net, c_node, node; low=true)
    n = Int(sqrt(size(net.graph)[1])) # grid size
    c_x = c_node%n == 0 ? c_node ÷ n : (c_node ÷ n) + 1
    c_y = c_node - n*(c_x-1)
    x = node%n == 0 ? node ÷ n : (node ÷ n) + 1
    y = node - n*(x-1)
    return low ? (c_x - x) >= 0 && (c_y - y) >= 0 : (c_x - x) <= 0 && (c_y - y) <= 0
end

## function for picking the furthest node
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

## without entanglement tracker - this is almost the same test as the one in test_entanglement_tracker.jl which tests a simple chain -- the only difference is that we have picked a few hardcoded arbitrary nodes through a grid (creating an ad-hoc chain)
paths = [
    [2, 3, 4, 8, 12],
    [2, 6, 7, 11, 15],
    [5, 9, 13, 14, 15],
    [2, 6, 10, 14, 15],
    [5, 6, 7, 8, 12],
    [5, 6, 10, 11, 12],
    [2, 3, 7, 11, 12]
] # some possible hardcoded paths for 4x4 grid setup
for path in paths
    graph = grid([4, 4])

    net = RegisterNet(graph, [Register(3) for i in 1:16])
    sim = get_time_tracker(net)


    entangler1 = EntanglerProt(sim, net, 1, path[1]; rounds=1)
    @process entangler1()
    run(sim, 20)

    @test net[1].tags == [[Tag(EntanglementCounterpart, path[1], 1)],[],[]]


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

    @test net[1].tags == [[Tag(EntanglementCounterpart, path[1], 1)],[],[]]
    @test net[path[1]].tags == [[Tag(EntanglementCounterpart, 1, 1)],[Tag(EntanglementCounterpart, path[2], 1)],[]]
    @test net[path[2]].tags == [[Tag(EntanglementCounterpart, path[1], 2)],[Tag(EntanglementCounterpart, path[3], 1)], []]
    @test net[path[3]].tags == [[Tag(EntanglementCounterpart, path[2], 2)],[Tag(EntanglementCounterpart, path[4], 1)], []]
    @test net[path[4]].tags == [[Tag(EntanglementCounterpart, path[3], 2)],[Tag(EntanglementCounterpart, path[5], 1)], []]
    @test net[path[5]].tags == [[Tag(EntanglementCounterpart, path[4], 2)],[Tag(EntanglementCounterpart, 16, 1)], []]
    @test net[16].tags == [[Tag(EntanglementCounterpart, path[5], 2)],[],[]]

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false

    l1(x) = check_nodes(net, path[1], x)
    h1(x) = check_nodes(net, path[1], x; low=false)
    cL1(arr) = choose_node(net, path[1], arr)
    cH1(arr) = choose_node(net, path[1], arr; low=false)
    swapper1 = SwapperProt(sim, net, path[1]; nodeL=l1, nodeH=h1, chooseL=cL1, chooseH=cH1, rounds=1)

    l2(x) = check_nodes(net, path[2], x)
    h2(x) = check_nodes(net, path[2], x; low=false)
    cL2(arr) = choose_node(net, path[2], arr)
    cH2(arr) = choose_node(net, path[2], arr; low=false)
    swapper2 = SwapperProt(sim, net, path[2]; nodeL=l2, nodeH=h2, chooseL=cL2, chooseH=cH2, rounds=1)

    l3(x) = check_nodes(net, path[3], x)
    h3(x) = check_nodes(net, path[3], x; low=false)
    cL3(arr) = choose_node(net, path[3], arr)
    cH3(arr) = choose_node(net, path[3], arr; low=false)
    swapper3 = SwapperProt(sim, net, path[3]; nodeL=l3, nodeH=h3, chooseL=cL3, chooseH=cH3, rounds=1)

    l4(x) = check_nodes(net, path[4], x)
    h4(x) = check_nodes(net, path[4], x; low=false)
    cL4(arr) = choose_node(net, path[4], arr)
    cH4(arr) = choose_node(net, path[4], arr; low=false)
    swapper4 = SwapperProt(sim, net, path[4]; nodeL=l4, nodeH=h4, chooseL=cL4, chooseH=cH4, rounds=1)

    l5(x) = check_nodes(net, path[5], x)
    h5(x) = check_nodes(net, path[5], x; low=false)
    cL5(arr) = choose_node(net, path[5], arr)
    cH5(arr) = choose_node(net, path[5], arr; low=false)
    swapper5 = SwapperProt(sim, net, path[5]; nodeL=l5, nodeH=h5, chooseL=cL5, chooseH=cH5, rounds=1)

    @process swapper1()
    @process swapper2()
    @process swapper3()
    @process swapper4()
    @process swapper5()
    run(sim, 200)

    # In the absence of an entanglement tracker the tags will not all be updated
    @test net[1].tags == [[Tag(EntanglementCounterpart, path[1], 1)],[],[]]
    @test net[path[1]].tags == [[Tag(EntanglementHistory, 1, 1, path[2], 1, 2)],[Tag(EntanglementHistory, path[2], 1, 1, 1, 1)],[]]
    @test net[path[2]].tags == [[Tag(EntanglementHistory, path[1], 2, path[3], 1, 2)],[Tag(EntanglementHistory, path[3], 1, path[1], 2, 1)], []]
    @test net[path[3]].tags == [[Tag(EntanglementHistory, path[2], 2, path[4], 1, 2)],[Tag(EntanglementHistory, path[4], 1, path[2], 2, 1)], []]
    @test net[path[4]].tags == [[Tag(EntanglementHistory, path[3], 2, path[5], 1, 2)],[Tag(EntanglementHistory, path[5], 1, path[3], 2, 1)], []]
    @test net[path[5]].tags == [[Tag(EntanglementHistory, path[4], 2, 16, 1, 2)],[Tag(EntanglementHistory, 16, 1, path[4], 2, 1)], []]
    @test net[16].tags == [[Tag(EntanglementCounterpart, path[5], 2)],[],[]]

    @test isassigned(net[1][1]) && isassigned(net[16][1])
    @test !isassigned(net[path[1]][1]) && !isassigned(net[path[2]][1])
    @test !isassigned(net[path[1]][2]) && !isassigned(net[path[2]][2])
    @test !isassigned(net[path[3]][1]) && !isassigned(net[path[4]][1])
    @test !isassigned(net[path[3]][2]) && !isassigned(net[path[4]][2])
    @test !isassigned(net[path[5]][1]) && !isassigned(net[path[5]][2])

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false

end

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

## with entanglement tracker -- here we hardcode the diagonal of the grid as the path on which we are making connections
for n in 4:10
    graph = grid([n,n])

    for i in 1:(n^2 - n + 1) # add diagonal channels
        add_edge!(graph, i, i + n + 1)
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

    run(sim, 100)

    q1 = query(net[1], EntanglementCounterpart, size(graph)[1], ❓)
    # q2 = query(net[size(graph)[1]], EntanglementCounterpart, 1, ❓)
    q2 = (slot=net[q1.tag[2]][q1.tag[3]], tag = net[q1.tag[2]].tags[q1.tag[3]][1])
    @test q1.tag[2] == size(graph)[1]
    @test q2.tag[2] == 1
    @test observable((q1.slot, q2.slot), Z⊗Z) ≈ 1.0
    @test observable((q1.slot, q2.slot), X⊗X) ≈ 1.0
end
