@testitem "ProtocolZoo Swapper chooseslots" tags=[:protocolzoo_swapper] begin
using Test
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ
using Graphs

struct SwapTag end

function choose_SwapTag_slots(reg, slots)
    results = queryall(reg, SwapTag)
    tagged_slots = [r.slot.idx for r in results]
    return slots in tagged_slots
end

# Tag-based filter
for i in 1:10
    n = 3
    net = RegisterNet([Register(4), Register(4), Register(4)])
    sim = get_time_tracker(net)

    for e in edges(net)
        eprot1 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=1, chooseslotB=2)
        @process eprot1()
        eprot2 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=3, chooseslotB=4)
        @process eprot2()
    end

    for j in vertices(net)
        tracker = EntanglementTracker(sim, net, j)
        @process tracker()
    end

    # Tag slots 1 and 2
    for j in 2:n-1
        tag!(net[j][1], Tag(SwapTag))
        tag!(net[j][2], Tag(SwapTag))
        swapper = SwapperProt(sim, net, j;
            chooseslots = (slots) -> choose_SwapTag_slots(net[j], slots),
            nodeL = <(j),
            nodeH = >(j),
            chooseL = argmin,
            chooseH = argmax,
            rounds = 1)
        @process swapper()
    end

    run(sim, 200)

    # Check that swap happened on tagged slots (1 and 2)
    q1 = query(net[1], EntanglementCounterpart, n, ❓)
    q2 = query(net[n], EntanglementCounterpart, 1, ❓)
    @test q1.tag[2] == n
    @test q2.tag[2] == 1
    @test observable((q1.slot, q2.slot), Z⊗Z) ≈ 1
    @test observable((q1.slot, q2.slot), X⊗X) ≈ 1

    # Entanglements in non-tagged slots (3 and 4) should not be swapped
    for k in 1:n-1
        @test observable([net[k], net[k+1]], [3, 4], projector((Z1⊗Z1 + Z2⊗Z2) / sqrt(2))) ≈ 1
    end
end


# Vector-based filtering

for i in 1:10
    n = 3
    net = RegisterNet([Register(4), Register(4), Register(4)])
    sim = get_time_tracker(net)

    for e in edges(net)
        eprot1 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=1, chooseslotB=2)
        @process eprot1()
        eprot2 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=3, chooseslotB=4)
        @process eprot2()
    end

    for j in vertices(net)
        tracker = EntanglementTracker(sim, net, j)
        @process tracker()
    end

    for j in 2:n-1
        swapper = SwapperProt(sim, net, j;
            chooseslots = [1, 2],
            nodeL = <(j),
            nodeH = >(j),
            chooseL = argmin,
            chooseH = argmax,
            rounds = 1)
        @process swapper()
    end

    run(sim, 200)

    # Check that swap happened on allowed slots (1 and 2)
    q1 = query(net[1], EntanglementCounterpart, n, ❓)
    q2 = query(net[n], EntanglementCounterpart, 1, ❓)
    @test q1.tag[2] == n
    @test q2.tag[2] == 1
    @test observable((q1.slot, q2.slot), Z⊗Z) ≈ 1
    @test observable((q1.slot, q2.slot), X⊗X) ≈ 1

    # Entanglements in non-allowed slots (3 and 4) should not be swapped
    for k in 1:n-1
        @test observable([net[k], net[k+1]], [3, 4], projector((Z1⊗Z1 + Z2⊗Z2) / sqrt(2))) ≈ 1
    end
end
end
