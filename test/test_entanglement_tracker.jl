using Revise
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ
using Graphs
using Test

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

##

# without an entanglement tracker

for i in 1:10

    net = RegisterNet([Register(3), Register(4), Register(2), Register(3)])
    sim = get_time_tracker(net)


    entangler1 = EntanglerProt(sim, net, 1, 2; rounds=1)
    @process entangler1()
    run(sim, 20)

    @test net[1].tags == [[Tag(EntanglementCounterpart, 2, 1)],[],[]]


    entangler2 = EntanglerProt(sim, net, 2, 3; rounds=1)
    @process entangler2()
    run(sim, 40)
    entangler3 = EntanglerProt(sim, net, 4, 3; rounds=1)
    @process entangler3()
    run(sim, 60)

    @test net[1].tags == [[Tag(EntanglementCounterpart, 2, 1)],[],[]]
    @test net[2].tags == [[Tag(EntanglementCounterpart, 1, 1)],[Tag(EntanglementCounterpart, 3, 1)],[],[]]
    @test net[3].tags == [[Tag(EntanglementCounterpart, 2, 2)],[Tag(EntanglementCounterpart, 4, 1)]]
    @test net[4].tags == [[Tag(EntanglementCounterpart, 3, 2)],[],[]]

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false


    swapper2 = SwapperProt(sim, net, 2; rounds=1)
    swapper3 = SwapperProt(sim, net, 3; rounds=1)
    @process swapper2()
    @process swapper3()
    run(sim, 80)

    # In the absence of an entanglement tracker the tags will not all be updated
    @test net[1].tags == [[Tag(EntanglementCounterpart, 2, 1)],[],[]]
    @test net[2].tags == [[Tag(EntanglementHistory, 1, 1, 3, 1, 2)],[Tag(EntanglementHistory, 3, 1, 1, 1, 1)],[],[]]
    @test net[3].tags == [[Tag(EntanglementHistory, 2, 2, 4, 1, 2)],[Tag(EntanglementHistory, 4, 1, 2, 2, 1)]]
    @test net[4].tags == [[Tag(EntanglementCounterpart, 3, 2)],[],[]]

    @test isassigned(net[1][1]) && isassigned(net[4][1])
    @test !isassigned(net[2][1]) && !isassigned(net[3][1])
    @test !isassigned(net[2][2]) && !isassigned(net[3][2])

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false

end

##

using Revise
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ
using Graphs
using Test
using Random

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

##

# same but this time with an entanglement tracker

for i in 1:30, n in 2:30
    #@show n, i
    net = RegisterNet([Register(j+3) for j in 1:n])
    sim = get_time_tracker(net)
    for j in vertices(net)
        tracker = EntanglementTracker(sim, net, j)
        @process tracker()
    end
    for e in edges(net)
        eprot = EntanglerProt(sim, net, e.src, e.dst; rounds=1, randomize=true)
        @process eprot()
    end
    for j in 2:n-1
        swapper = SwapperProt(sim, net, j; rounds=1)
        @process swapper()
    end
    run(sim, 200)

    q1 = query(net[1], EntanglementCounterpart, n, ❓)
    q2 = query(net[n], EntanglementCounterpart, 1, ❓)
    @test q1.tag[2] == n
    @test q2.tag[2] == 1
    @test observable((q1.slot, q2.slot), Z⊗Z) ≈ 1
    @test observable((q1.slot, q2.slot), X⊗X) ≈ 1
end


# Tests with 2d Grid

## Custom Predicates
function top_left(net, node, x)
    n = sqrt(size(net.graph)[1]) # grid size
    a = (node ÷ n) + 1 # row number
    for i in 1:a-1
        if x == (i-1)*n + i
            return true
        end
    end
    return false
end

function bottom_right(net, node, x)
    n = sqrt(size(net.graph)[1]) # grid size
    a = (node ÷ n) + 1 # row number
    for i in a+1:n
        if x == (i-1)*n + i
            return true
        end
    end
    return false
end

## Simulation

#without entanglement tracker
for i in 1:10
    graph = grid([4, 4])
    add_edge!(graph, 1, 6)
    add_edge!(graph, 6, 11)
    add_edge!(graph, 11, 16)
    
    net = RegisterNet(graph, [Register(3) for i in 1:16])
    sim = get_time_tracker(net)


    entangler1 = EntanglerProt(sim, net, 1, 6; rounds=1)
    @process entangler1()
    run(sim, 20)

    @test net[1].tags == [[Tag(EntanglementCounterpart, 6, 1)],[],[]]


    entangler2 = EntanglerProt(sim, net, 6, 11; rounds=1)
    @process entangler2()
    run(sim, 40)
    entangler3 = EntanglerProt(sim, net, 11, 16; rounds=1)
    @process entangler3()
    run(sim, 60)

    @test net[1].tags == [[Tag(EntanglementCounterpart, 6, 1)],[],[]]
    @test net[6].tags == [[Tag(EntanglementCounterpart, 1, 1)],[Tag(EntanglementCounterpart, 11, 1)],[]]
    @test net[11].tags == [[Tag(EntanglementCounterpart, 6, 2)],[Tag(EntanglementCounterpart, 16, 1)], []]
    @test net[16].tags == [[Tag(EntanglementCounterpart, 11, 2)],[],[]]

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false

    l1(x) = top_left(net, 6, x)
    h1(x) = bottom_right(net, 6, x)
    swapper2 = SwapperProt(sim, net, 6; nodeL=l1, nodeR=h1, rounds=1)
    l2(x) = top_left(net, 11, x)
    h2(x) = bottom_right(net, 11, x)
    swapper3 = SwapperProt(sim, net, 11; nodeL=l2, nodeR=h2, rounds=1)
    @process swapper2()
    @process swapper3()
    run(sim, 80)

    # In the absence of an entanglement tracker the tags will not all be updated
    @test net[1].tags == [[Tag(EntanglementCounterpart, 6, 1)],[],[]]
    @test net[6].tags == [[Tag(EntanglementHistory, 1, 1, 11, 1, 2)],[Tag(EntanglementHistory, 11, 1, 1, 1, 1)],[]]
    @test net[11].tags == [[Tag(EntanglementHistory, 6, 2, 16, 1, 2)],[Tag(EntanglementHistory, 16, 1, 6, 2, 1)], []]
    @test net[16].tags == [[Tag(EntanglementCounterpart, 11, 2)],[],[]]

    @test isassigned(net[1][1]) && isassigned(net[16][1])
    @test !isassigned(net[6][1]) && !isassigned(net[11][1])
    @test !isassigned(net[6][2]) && !isassigned(net[11][2])

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false

end

# with entanglement tracker
for n in 4:10
    graph = grid([n,n])
    
    diag_pairs = []
    diag_nodes = []
    reg_num = 1 # starting register
    for i in 1:n-1 # a grid with n nodes has n-1 pairs of diagonal nodes
        push!(diag_pairs, (reg_num, reg_num+n+1))
        push!(diag_nodes, reg_num)
        reg_num += n + 1
    end
    push!(diag_nodes, n^2)

    for (src, dst) in diag_pairs # need edges down the diagonal to establish cchannels and qchannels between the diagonal nodes
        add_edge!(graph, src, dst)
    end

    net = RegisterNet(graph, [Register(8) for i in 1:n^2])

    sim = get_time_tracker(net)

    for (src, dst) in diag_pairs
        eprot = EntanglerProt(sim, net, src, dst; rounds=1, randomize=true)
        @process eprot()
    end

    for i in 2:n-1
        l(x) = top_left(net, diag_nodes[i], x)
        h(x) = bottom_right(net, diag_nodes[i], x)
        swapper = SwapperProt(sim, net, diag_nodes[i]; nodeL = l, nodeR = h, rounds = 1)
        @process swapper()
    end

    for v in diag_nodes
        tracker = EntanglementTracker(sim, net, v)
        @process tracker()
    end

    run(sim, 200)

    q1 = query(net[1], EntanglementCounterpart, diag_nodes[n], ❓)
    q2 = query(net[diag_nodes[n]], EntanglementCounterpart, 1, ❓)
    @test q1.tag[2] == diag_nodes[n]
    @test q2.tag[2] == 1
    @test observable((q1.slot, q2.slot), Z⊗Z) ≈ 1
    @test observable((q1.slot, q2.slot), X⊗X) ≈ 1
end
