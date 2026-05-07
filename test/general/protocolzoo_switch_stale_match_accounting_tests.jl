using Test
using Graphs: star_graph
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory

const Switches = QuantumSavory.ProtocolZoo.Switches

@testset "ProtocolZoo Switch stale match accounting" begin
    net = RegisterNet(star_graph(3), [Register(2), Register(1), Register(1)])
    sim = get_time_tracker(net)
    switch = SimpleSwitchDiscreteProt(net, 1, [2, 3], [1.0, 1.0]; ticktock=1.0, rounds=1)
    reverseclientindex = Dict(2 => 1, 3 => 2)
    switch._backlog[1, 2] = 1

    initialize!((net[1][1], net[2][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
    tag!(net[1][1], EntanglementCounterpart, 2, 1)
    tag!(net[2][1], EntanglementCounterpart, 1, 1)

    initialize!((net[1][2], net[3][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
    tag!(net[1][2], EntanglementCounterpart, 3, 1)
    tag!(net[3][1], EntanglementCounterpart, 1, 2)

    match = Switches._switch_successful_entanglements_best_match(switch, reverseclientindex)
    @test !isnothing(match)
    @test switch._backlog[1, 2] == 1

    for (switchslot, clientnode, clientslot) in ((1, 2, 1), (2, 3, 1))
        switchtag = query(net[1][switchslot], EntanglementCounterpart, clientnode, clientslot)
        clienttag = query(net[clientnode][clientslot], EntanglementCounterpart, 1, switchslot)
        untag!(net[1][switchslot], switchtag.id)
        untag!(net[clientnode][clientslot], clienttag.id)
        traceout!(net[1][switchslot], net[clientnode][clientslot])
    end

    Switches._switch_run_swaps(switch, match)
    run(sim, 0.2)

    @test isempty(queryall(net[1], EntanglementHistory, ❓, ❓, ❓, ❓, ❓))
    @test switch._backlog[1, 2] == 1
end
