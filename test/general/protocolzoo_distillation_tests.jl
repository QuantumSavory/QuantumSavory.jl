using Test
using ResumableFunctions
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo: BBPSSWProt, DistilledTag, EntanglerProt, EntanglementCounterpart, EntanglementDelete
using QuantumSavory.ProtocolZoo: BBPSSWMessage, finddistillablequbits, fresh_entanglement_id, permits_virtual_edge
using Graphs

const _bbpssw_bell = (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0)

function _tagged_bell_pair!(net, slot; pair_id=fresh_entanglement_id())
    initialize!((net[1][slot], net[2][slot]), _bbpssw_bell)
    tag!(net[1][slot], EntanglementCounterpart, 2, slot, pair_id)
    tag!(net[2][slot], EntanglementCounterpart, 1, slot, pair_id)
    return pair_id
end

function _choose_slot_pair(target_slot, sacrificed_slot)
    return pairs -> (
        only(pair for pair in pairs if pair[1].slot.idx == target_slot),
        only(pair for pair in pairs if pair[1].slot.idx == sacrificed_slot),
    )
end

@testset "BBPSSWProt entanglement id matching" begin
    net = RegisterNet([Register(2), Register(2)])
    pair_id = fresh_entanglement_id()
    mismatched_id = fresh_entanglement_id()

    initialize!((net[1][1], net[2][1]), _bbpssw_bell)
    tag!(net[1][1], EntanglementCounterpart, 2, 1, pair_id)
    tag!(net[2][1], EntanglementCounterpart, 1, 1, mismatched_id)
    _tagged_bell_pair!(net, 2)

    selected = finddistillablequbits(net, 1, 2, Returns(true), Returns(true), pairs -> (pairs[1], pairs[2]))
    @test isnothing(selected)

    querydelete!(net[2][1], EntanglementCounterpart, 1, 1, mismatched_id)
    tag!(net[2][1], EntanglementCounterpart, 1, 1, pair_id)
    selected = finddistillablequbits(net, 1, 2, Returns(true), Returns(true), pairs -> (pairs[1], pairs[2]))
    @test !isnothing(selected)
end

@testset "BBPSSWProt pair ids, messages, and cleanup" begin
    @test permits_virtual_edge(BBPSSWProt(RegisterNet([Register(2), Register(2)]), 1, 2; rounds=0))

    net = RegisterNet([Register(2), Register(2)])
    sim = get_time_tracker(net)
    target_pair_id = _tagged_bell_pair!(net, 1)
    sacrificed_pair_id = _tagged_bell_pair!(net, 2)
    stale_pair_id = fresh_entanglement_id()
    put!(messagebuffer(net, 2), Tag(BBPSSWMessage, 1, stale_pair_id, sacrificed_pair_id, 1))

    distiller = BBPSSWProt(
        sim,
        net,
        1,
        2;
        rounds=1,
        choose_pairs=_choose_slot_pair(1, 2),
        max_delete_per_slot=1,
    )
    @process distiller()
    run(sim, 200)

    @test !isnothing(query(net[1][1], EntanglementCounterpart, 2, 1, target_pair_id))
    @test !isnothing(query(net[2][1], EntanglementCounterpart, 1, 1, target_pair_id))
    @test !isnothing(query(net[1][1], DistilledTag))
    @test !isnothing(query(net[2][1], DistilledTag))
    @test isnothing(query(net[1][2], EntanglementCounterpart, 2, 2, sacrificed_pair_id))
    @test isnothing(query(net[2][2], EntanglementCounterpart, 1, 2, sacrificed_pair_id))
    @test !isnothing(query(net[1][2], EntanglementDelete, sacrificed_pair_id, 1, 2, 2, 2))
    @test !isnothing(query(net[2][2], EntanglementDelete, sacrificed_pair_id, 2, 2, 1, 2))
    @test !isnothing(query(messagebuffer(net, 2), BBPSSWMessage, 1, stale_pair_id, sacrificed_pair_id, 1))

    failure_net = RegisterNet([Register(2), Register(2)])
    failure_sim = get_time_tracker(failure_net)
    failed_target_pair_id = _tagged_bell_pair!(failure_net, 1)
    failed_sacrificed_pair_id = _tagged_bell_pair!(failure_net, 2)
    apply!(failure_net[1][2], Z)
    tag!(failure_net[1][2], EntanglementDelete, fresh_entanglement_id(), 1, 2, 2, 99)

    failed_distiller = BBPSSWProt(
        failure_sim,
        failure_net,
        1,
        2;
        rounds=1,
        choose_pairs=_choose_slot_pair(1, 2),
        max_delete_per_slot=1,
    )
    @process failed_distiller()
    run(failure_sim, 200)

    @test isnothing(query(failure_net[1][1], EntanglementCounterpart, 2, 1, failed_target_pair_id))
    @test isnothing(query(failure_net[2][1], EntanglementCounterpart, 1, 1, failed_target_pair_id))
    @test !isassigned(failure_net[1][1])
    @test !isassigned(failure_net[2][1])
    @test !isnothing(query(failure_net[1][1], EntanglementDelete, failed_target_pair_id, 1, 1, 2, 1))
    @test !isnothing(query(failure_net[2][1], EntanglementDelete, failed_target_pair_id, 2, 1, 1, 1))
    delete_tags = queryall(failure_net[1][2], EntanglementDelete, ❓, 1, 2, ❓, ❓; filo=false)
    @test [delete_tag.tag[2] for delete_tag in delete_tags] == [failed_sacrificed_pair_id]
end

@testset "BBPSSWProt chooseslots nondistilled" begin
    for i in 1:10
        n = 2
        net = RegisterNet([Register(2), Register(2), Register(2), Register(2)])
        sim = get_time_tracker(net)

        # Entangle node 1 and 2, and node 3 and 4
        for e in edges(net)
            if e.src == 2 && e.dst == 3
                continue
            end
            eprot1 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=1, chooseslotB=1)
            @process eprot1()
            eprot2 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=2, chooseslotB=2)
            @process eprot2()
        end

        # tag slot 1 of nodes 3 and 4 as already distilled. Should be ignored by distiller
        tag!(net[3][1], DistilledTag)
        tag!(net[4][1], DistilledTag)

        distiller_12 = BBPSSWProt(sim, net, 1, 2; rounds=1)
        @process distiller_12()
        distiller_34 = BBPSSWProt(sim, net, 3, 4; rounds=1)
        @process distiller_34()


        run(sim, 200)

        # Check that distilled entanglement exists on both nodes
        q1 = queryall(net[1], DistilledTag)
        q2 = queryall(net[2], DistilledTag)
        @test (q1 !== nothing) && (length(q1) == 1)
        @test (q2 !== nothing) && (length(q2) == 1)

        # retrieve the distilled slots
        slot1 = q1[1].slot
        slot2 = q2[1].slot
        @test slot1.idx == slot2.idx

        # Check that the distilled entanglement is a Bell pair
        @test observable((slot1, slot2), Z⊗Z) ≈ 1
        @test observable((slot1, slot2), X⊗X) ≈ 1

        # Check that the second Bell pair used in distillation was traced out and is now unassigned
        other_slot1 = net[1][3 - slot1.idx]
        other_slot2 = net[2][3 - slot2.idx]
        @test findfreeslot(net[1]) === other_slot1
        @test findfreeslot(net[2]) === other_slot2

        # Check that slots between 3 and 4 did not change. There should still be 2 Bell pairs
        for k in 1:2
            @test observable((net[3][k], net[4][k]), Z⊗Z) ≈ 1
            @test observable((net[3][k], net[4][k]), X⊗X) ≈ 1
        end
    end
    
end

@testset "BBPSSWProt fidelity improvement" begin
    for i in 1:20
        n = 2
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)
        initial_W = 0.9

        # Define depolarized Bell pair state TODO: use the helper when available
        perfect_pair_dm = SProjector((Z₁ ⊗ Z₁ + Z₂ ⊗ Z₂) / sqrt(2))
        mixed_dm = MixedState(perfect_pair_dm)
        depolarized_pair(W) = W*perfect_pair_dm + (1-W)*mixed_dm 

        # Entangle node 1 and 2 with noisy entanglement
        for e in edges(net)
            eprot1 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=1, chooseslotB=1, pairstate=depolarized_pair(initial_W))
            @process eprot1()
            eprot2 = EntanglerProt(sim, net, e.src, e.dst; rounds=1, success_prob=1.0, chooseslotA=2, chooseslotB=2, pairstate=depolarized_pair(initial_W))
            @process eprot2()
        end

        distiller = BBPSSWProt(sim, net, 1, 2; rounds=1)
        @process distiller()

        run(sim, 200)

        # Check that distilled entanglement exists on both nodes (if distillation succeeded)
        q1 = queryall(net[1], DistilledTag)
        q2 = queryall(net[2], DistilledTag)
        @test (q1 !== nothing) && (length(q1) <= 1)
        @test (q2 !== nothing) && (length(q2) <= 1)
        @test length(q1) == length(q2)

        if length(q1) == 1
            # retrieve the distilled slots
            slot1 = q1[1].slot
            slot2 = q2[1].slot
            @test slot1.idx == slot2.idx

            # Check that the distilled entanglement has improved fidelity
            f_before = (3*initial_W + 1) / 4  # fidelity of depolarized Bell pair
            f_after = abs(observable((slot1, slot2), SProjector((Z₁ ⊗ Z₁ + Z₂ ⊗ Z₂) / sqrt(2))))
            @test f_after > f_before

            # check that the second Bell pair used in distillation was traced out and is now unassigned
            other_slot1 = net[1][3 - slot1.idx]
            other_slot2 = net[2][3 - slot2.idx]
            @test findfreeslot(net[1]) === other_slot1
            @test findfreeslot(net[2]) === other_slot2
        else
            # Check that both slots are now free at both nodes
            unassigned_slot_1 = findfreeslot(net[1])
            unassigned_slot_2 = findfreeslot(net[2])
            @test unassigned_slot_1 !== nothing
            @test unassigned_slot_2 !== nothing

            initialize!(unassigned_slot_1, Z1)
            initialize!(unassigned_slot_2, Z1)
            # There should be another free slot
            @test findfreeslot(net[1]) !== nothing
            @test findfreeslot(net[2]) !== nothing
        end
    end

end
