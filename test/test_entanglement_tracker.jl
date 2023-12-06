using Revise
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ
using Graphs
using Test

using Logging
logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black,"",""))
global_logger(logger)

##

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
#@test observable((net[1][1], net[4][1]), Z⊗Z) ≈ 1
@test !isassigned(net[2][1]) && !isassigned(net[3][1])
@test !isassigned(net[2][2]) && !isassigned(net[3][2])

@test [islocked(ref) for i in vertices(net) for ref in net[i]] |> any == false


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

using Logging
logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black,"",""))
global_logger(logger)
# same but this time with an entanglement tracker
n = 5 # works at <5
for i in 1:1000
    println("new =======================\n\n")
    net = RegisterNet([Register(i+3) for i in 1:n])
    sim = get_time_tracker(net)
    for i in vertices(net)
        tracker = EntanglementTracker(sim, net, i)
        @process tracker()
    end
    for e in edges(net)
        eprot = EntanglerProt(sim, net, e.src, e.dst; rounds=1)
        @process eprot()
    end
    for i in 2:n-1
        swapper = SwapperProt(sim, net, i; rounds=1)
        @process swapper()
    end
    run(sim, 200)

    @test net[1].tags[1] == [Tag(EntanglementCounterpart, n, 1)]
    @test net[n].tags[1] == [Tag(EntanglementCounterpart, 1, 1)]
    #@test observable((net[1][1], net[n][1]), Z⊗Z) ≈ 1
end
