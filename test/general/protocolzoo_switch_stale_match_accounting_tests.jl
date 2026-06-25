using Test
using Graphs: star_graph
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory

const Switches = QuantumSavory.ProtocolZoo.Switches

@testset "ProtocolZoo Switch stale match accounting" begin
    # This test is extremely contrived:
    # It tests that the swapper called by the switch is resilient to a situation
    # in which an async unrelated process has destroyed the qubits that were about to be swappe.
    # However, permitting situation like that in the first place would be a failure of
    # protocol parameter choice and a failure to properly lock qubits.

    net = RegisterNet(star_graph(3), [Register(2), Register(1), Register(1)])
    sim = get_time_tracker(net)
    switch = SimpleSwitchDiscreteProt(net, 1, [2, 3], [1.0, 1.0]; ticktock=1.0, rounds=1)
    reverseclientindex = Dict(2 => 1, 3 => 2)
    switch._backlog[1, 2] = 1
    left_pair_id = 101
    right_pair_id = 202

    initialize!((net[1][1], net[2][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
    tag!(net[1][1], EntanglementCounterpart, 2, 1, left_pair_id)
    tag!(net[2][1], EntanglementCounterpart, 1, 1, left_pair_id)

    initialize!((net[1][2], net[3][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
    tag!(net[1][2], EntanglementCounterpart, 3, 1, right_pair_id)
    tag!(net[3][1], EntanglementCounterpart, 1, 2, right_pair_id)

    match = Switches._switch_successful_entanglements_best_match(switch, reverseclientindex)
    @test !isnothing(match)
    @test switch._backlog[1, 2] == 1

    for (switchslot, clientnode, clientslot) in ((1, 2, 1), (2, 3, 1))
        switchtag = query(net[1][switchslot], EntanglementCounterpart, clientnode, clientslot, ❓)
        clienttag = query(net[clientnode][clientslot], EntanglementCounterpart, 1, switchslot, switchtag.tag[4])
        untag!(net[1][switchslot], switchtag.id)
        untag!(net[clientnode][clientslot], clienttag.id)
        traceout!(net[1][switchslot], net[clientnode][clientslot])
    end

    Switches._switch_run_swaps(switch, match)
    run(sim, 0.2)

    @test isempty(queryall(net[1], EntanglementHistory, ❓, ❓, ❓, ❓, ❓, ❓, ❓))
    @test switch._backlog[1, 2] == 1
end
