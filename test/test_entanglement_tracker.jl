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

    @test [net[1].tag_info[i][1] for i in net[1].guids] == [Tag(EntanglementCounterpart, 2, 1)]

    entangler2 = EntanglerProt(sim, net, 2, 3; rounds=1)
    @process entangler2()
    run(sim, 40)
    entangler3 = EntanglerProt(sim, net, 4, 3; rounds=1)
    @process entangler3()
    run(sim, 60)

    @test [net[1].tag_info[i][1] for i in net[1].guids] == [Tag(EntanglementCounterpart, 2, 1)]
    @test [net[2].tag_info[i][1] for i in net[2].guids] == [Tag(EntanglementCounterpart, 1, 1), Tag(EntanglementCounterpart, 3, 1)]
    @test [net[3].tag_info[i][1] for i in net[3].guids] == [Tag(EntanglementCounterpart, 2, 2), Tag(EntanglementCounterpart, 4, 1)]
    @test [net[4].tag_info[i][1] for i in net[4].guids] == [Tag(EntanglementCounterpart, 3, 2)]

    @test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false


    swapper2 = SwapperKeeper(sim, net, 2; nodeL = <(2), nodeH = >(2), chooseL = argmin, chooseH = argmax, rounds = 1)
    swapper3 = SwapperKeeper(sim, net, 3; nodeL = <(3), nodeH = >(3), chooseL = argmin, chooseH = argmax, rounds = 1)
    @process swapper2()
    @process swapper3()
    run(sim, 80)

    # In the absence of an entanglement tracker the tags will not all be updated
    @test [net[1].tag_info[i][1] for i in net[1].guids] == [Tag(EntanglementCounterpart, 2, 1)]
    @test [net[2].tag_info[i][1] for i in net[2].guids] == [Tag(EntanglementHistory, 1, 1, 3, 1, 2),Tag(EntanglementHistory, 3, 1, 1, 1, 1)]
    @test [net[3].tag_info[i][1] for i in net[3].guids] == [Tag(EntanglementHistory, 2, 2, 4, 1, 2), Tag(EntanglementHistory, 4, 1, 2, 2, 1)]
    @test [net[4].tag_info[i][1] for i in net[4].guids] == [Tag(EntanglementCounterpart, 3, 2)]

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
        swapper = SwapperKeeper(sim, net, j; nodeL = <(j), nodeH = >(j), chooseL = argmin, chooseH = argmax, rounds = 1)
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
