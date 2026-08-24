using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using Test

struct QTCPExternalInventoryTag <: AbstractTag
    remote_node::Int
    remote_slot::Int
end

QuantumSavory.Tag(tag::QTCPExternalInventoryTag) =
    QuantumSavory.Tag(QTCPExternalInventoryTag, tag.remote_node, tag.remote_slot)

function generate_inventory_pair!(
    net, slot_a::Int, slot_b::Int=slot_a; tag=EntanglementCounterpart
)
    sim = get_time_tracker(net)
    entangler = EntanglerProt(
        net,
        1,
        2;
        tag,
        rounds=1,
        attempts=-1,
        success_prob=1.0,
        attempt_time=0.1,
        chooseslotA=slot_a,
        chooseslotB=slot_b,
    )
    @process entangler()
    run(sim, now(sim) + 0.2)
    return nothing
end

function inventory_tag(net, node, slot, remote_node, remote_slot, tag)
    if tag === EntanglementCounterpart
        return query(
            net[node][slot], tag, remote_node, remote_slot, ❓; assigned=true
        )
    end
    return query(net[node][slot], tag, remote_node, remote_slot; assigned=true)
end

function submit_link_request!(
    net, originator_node, destination_node; flow_uuid=1, seq_num=1
)
    put!(
        net[originator_node],
        LinkLevelRequest(flow_uuid, seq_num, destination_node),
    )
    run(get_time_tracker(net), now(get_time_tracker(net)) + 0.1)
    return nothing
end

@testset "QTCP LinkController external inventory" begin
    @testset "constructor modes and validation" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)

        integrated = LinkController(net, 1, 2)
        @test integrated.tag === nothing
        @test integrated.filo === nothing
        @test LinkController(net, 1, 2; tag=nothing, filo=nothing) isa
            LinkController

        external = LinkController(net, 1, 2; tag=EntanglementCounterpart)
        @test external.tag === EntanglementCounterpart
        @test external.filo === true
        @test LinkController(
            sim=sim,
            net=net,
            nodeA=1,
            nodeB=2,
            tag=QTCPExternalInventoryTag,
            filo=false,
        ).filo === false

        @test_throws ArgumentError LinkController(net, 1, 2; filo=true)
        @test_throws ArgumentError LinkController(
            net, 1, 2; tag=nothing, filo=false
        )
        @test_throws ArgumentError LinkController(
            net, 1, 2; tag=EntanglementCounterpart, filo=nothing
        )
        @test_throws ArgumentError LinkController(net, 1, 2; tag=AbstractTag)
    end

    @testset "newest and oldest reciprocal pairs are claimed" begin
        cases = (
            ("standard newest default", EntanglementCounterpart, nothing, 2),
            ("standard oldest", EntanglementCounterpart, false, 1),
            ("custom newest default", QTCPExternalInventoryTag, nothing, 2),
            ("custom oldest", QTCPExternalInventoryTag, false, 1),
        )

        for (name, tag, configured_filo, selected_slot) in cases
            @testset "$name" begin
                net = RegisterNet([Register(3), Register(3)])
                generate_inventory_pair!(net, 1; tag)
                generate_inventory_pair!(net, 2; tag)

                pair_1 = inventory_tag(net, 1, 1, 2, 1, tag)
                pair_2 = inventory_tag(net, 1, 2, 2, 2, tag)
                @test pair_1.time < pair_2.time

                unselected_slot = selected_slot == 1 ? 2 : 1
                unselected_a = inventory_tag(
                    net, 1, unselected_slot, 2, unselected_slot, tag
                )
                unselected_b = inventory_tag(
                    net, 2, unselected_slot, 1, unselected_slot, tag
                )
                unselected_state = QuantumSavory.stateof(net[1][unselected_slot])
                selected_state = QuantumSavory.stateof(net[1][selected_slot])

                controller = if isnothing(configured_filo)
                    LinkController(net, 1, 2; tag)
                else
                    LinkController(net, 1, 2; tag, filo=configured_filo)
                end
                @process controller()
                submit_link_request!(net, 1, 2; flow_uuid=10)

                reply = query(
                    messagebuffer(net, 1), LinkLevelReply, 10, 1, ❓
                )
                hop_reply = query(
                    messagebuffer(net, 2), LinkLevelReplyAtHop, 10, 1, ❓
                )
                @test !isnothing(reply)
                @test !isnothing(hop_reply)
                if !isnothing(reply) && !isnothing(hop_reply)
                    @test reply.tag[4] == selected_slot
                    @test hop_reply.tag[4] == selected_slot
                end

                @test isnothing(inventory_tag(
                    net, 1, selected_slot, 2, selected_slot, tag
                ))
                @test isnothing(inventory_tag(
                    net, 2, selected_slot, 1, selected_slot, tag
                ))
                @test isassigned(net[1][selected_slot])
                @test isassigned(net[2][selected_slot])
                @test selected_state ===
                    QuantumSavory.stateof(net[1][selected_slot]) ===
                    QuantumSavory.stateof(net[2][selected_slot])

                remaining_a = inventory_tag(
                    net, 1, unselected_slot, 2, unselected_slot, tag
                )
                remaining_b = inventory_tag(
                    net, 2, unselected_slot, 1, unselected_slot, tag
                )
                @test remaining_a.id == unselected_a.id
                @test remaining_b.id == unselected_b.id
                @test QuantumSavory.stateof(net[1][unselected_slot]) ===
                    unselected_state ===
                    QuantumSavory.stateof(net[2][unselected_slot])
                @test all(!islocked(net[node][slot]) for node in 1:2 for slot in 1:3)
            end
        end
    end

    @testset "a request waits for later inventory" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)
        controller = LinkController(net, 1, 2; tag=EntanglementCounterpart)
        @process controller()

        put!(net[1], LinkLevelRequest(20, 1, 2))
        run(sim, 0.5)
        @test isnothing(query(
            messagebuffer(net, 1), LinkLevelReply, 20, 1, ❓
        ))
        @test length(controller._log) == 1
        @test isnothing(only(controller._log).sojourn_time)

        generate_inventory_pair!(net, 1)
        run(sim, now(sim) + 0.1)
        @test query(messagebuffer(net, 1), LinkLevelReply, 20, 1, 1) !==
            nothing
        @test query(messagebuffer(net, 2), LinkLevelReplyAtHop, 20, 1, 1) !==
            nothing
        @test only(controller._log).sojourn_time > 0
    end

    @testset "a lock-only change resumes a waiting claim" begin
        net = RegisterNet([Register(2), Register(2)])
        sim = get_time_tracker(net)
        generate_inventory_pair!(net, 1)
        lock(net[1][1])
        @test islocked(net[1][1])

        @process LinkController(net, 1, 2; tag=EntanglementCounterpart)()
        put!(net[1], LinkLevelRequest(30, 1, 2))
        run(sim, now(sim) + 0.1)
        @test isnothing(query(
            messagebuffer(net, 1), LinkLevelReply, 30, 1, ❓
        ))

        unlock(net[1][1])
        run(sim, now(sim) + 0.1)
        @test query(messagebuffer(net, 1), LinkLevelReply, 30, 1, 1) !==
            nothing
        @test isnothing(inventory_tag(
            net, 1, 1, 2, 1, EntanglementCounterpart
        ))
        @test isnothing(inventory_tag(
            net, 2, 1, 1, 1, EntanglementCounterpart
        ))
        @test !islocked(net[1][1])
        @test !islocked(net[2][1])
    end

    @testset "stale and mismatched tags are skipped without partial deletion" begin
        net = RegisterNet([Register(4), Register(4)])
        for slot in 1:3
            generate_inventory_pair!(net, slot)
        end

        asymmetric_a = inventory_tag(
            net, 1, 3, 2, 3, EntanglementCounterpart
        )
        asymmetric_b = inventory_tag(
            net, 2, 3, 1, 3, EntanglementCounterpart
        )
        untag!(net[2][3], asymmetric_b.id)

        mismatched_a = inventory_tag(
            net, 1, 2, 2, 2, EntanglementCounterpart
        )
        mismatched_b = inventory_tag(
            net, 2, 2, 1, 2, EntanglementCounterpart
        )
        untag!(net[2][2], mismatched_b.id)
        wrong_pair_id = mismatched_a.tag[4] == 1 ? 2 : 1
        wrong_b_id = tag!(
            net[2][2], EntanglementCounterpart, 1, 2, wrong_pair_id
        )

        @process LinkController(net, 1, 2; tag=EntanglementCounterpart)()
        submit_link_request!(net, 1, 2; flow_uuid=40)

        reply = query(messagebuffer(net, 1), LinkLevelReply, 40, 1, ❓)
        @test !isnothing(reply)
        isnothing(reply) || @test reply.tag[4] == 1
        @test isnothing(inventory_tag(
            net, 1, 1, 2, 1, EntanglementCounterpart
        ))
        @test isnothing(inventory_tag(
            net, 2, 1, 1, 1, EntanglementCounterpart
        ))

        @test query(
            net[1][3], asymmetric_a.tag; assigned=true
        ).id == asymmetric_a.id
        @test isempty(queryall(
            net[2][3], EntanglementCounterpart, 1, 3, ❓
        ))
        @test query(
            net[1][2], mismatched_a.tag; assigned=true
        ).id == mismatched_a.id
        @test query(
            net[2][2], EntanglementCounterpart, 1, 2, wrong_pair_id;
            assigned=true
        ).id == wrong_b_id
        @test all(!islocked(net[node][slot]) for node in 1:2 for slot in 1:4)
    end

    @testset "duplicate inventory tags are never claimed" begin
        net = RegisterNet([Register(3), Register(3)])
        sim = get_time_tracker(net)
        generate_inventory_pair!(net, 1)
        generate_inventory_pair!(net, 2)

        newer_a = inventory_tag(
            net, 1, 2, 2, 2, EntanglementCounterpart
        )
        newer_b = inventory_tag(
            net, 2, 2, 1, 2, EntanglementCounterpart
        )
        duplicate_a_id = tag!(net[1][2], newer_a.tag)
        duplicate_b_id = tag!(net[2][2], newer_b.tag)

        controller = LinkController(
            net, 1, 2; tag=EntanglementCounterpart
        )
        @process controller()
        submit_link_request!(net, 1, 2; flow_uuid=45)
        @test query(messagebuffer(net, 1), LinkLevelReply, 45, 1, 1) !==
            nothing

        put!(net[1], LinkLevelRequest(46, 1, 2))
        run(sim, now(sim) + 0.1)
        @test isnothing(query(
            messagebuffer(net, 1), LinkLevelReply, 46, 1, ❓
        ))
        @test isnothing(last(controller._log).sojourn_time)

        remaining_a = queryall(net[1][2], newer_a.tag; assigned=true)
        remaining_b = queryall(net[2][2], newer_b.tag; assigned=true)
        @test Set(result.id for result in remaining_a) ==
            Set((newer_a.id, duplicate_a_id))
        @test Set(result.id for result in remaining_b) ==
            Set((newer_b.id, duplicate_b_id))
        @test isassigned(net[1][2])
        @test isassigned(net[2][2])
        @test all(!islocked(net[node][slot]) for node in 1:2 for slot in 1:3)
    end

    @testset "assignment invalidation retries without leaking locks" begin
        net = RegisterNet([Register(3), Register(3)])
        sim = get_time_tracker(net)
        generate_inventory_pair!(net, 1)
        generate_inventory_pair!(net, 2)
        invalidated_a = inventory_tag(
            net, 1, 2, 2, 2, EntanglementCounterpart
        )
        invalidated_b = inventory_tag(
            net, 2, 2, 1, 2, EntanglementCounterpart
        )

        lock(net[1][2])
        @process LinkController(net, 1, 2; tag=EntanglementCounterpart)()
        put!(net[1], LinkLevelRequest(50, 1, 2))
        run(sim, now(sim) + 0.1)

        traceout!(net[1][2], net[2][2])
        unlock(net[1][2])
        run(sim, now(sim) + 0.1)

        reply = query(messagebuffer(net, 1), LinkLevelReply, 50, 1, ❓)
        @test !isnothing(reply)
        isnothing(reply) || @test reply.tag[4] == 1
        @test query(net[1][2], invalidated_a.tag).id == invalidated_a.id
        @test query(net[2][2], invalidated_b.tag).id == invalidated_b.id
        @test !isassigned(net[1][2])
        @test !isassigned(net[2][2])
        @test all(!islocked(net[node][slot]) for node in 1:2 for slot in 1:3)
    end

    @testset "opposite-direction requests claim each pair once" begin
        net = RegisterNet([Register(5), Register(5)])
        sim = get_time_tracker(net)
        pair_slots = ((1, 3), (2, 4))
        for (slot_a, slot_b) in pair_slots
            generate_inventory_pair!(net, slot_a, slot_b)
        end

        @process LinkController(net, 1, 2; tag=EntanglementCounterpart)()
        put!(net[1], LinkLevelRequest(61, 1, 2))
        put!(net[2], LinkLevelRequest(62, 1, 1))
        run(sim, now(sim) + 0.1)

        mb1 = messagebuffer(net, 1)
        mb2 = messagebuffer(net, 2)
        reply_1 = querydelete!(mb1, LinkLevelReply, 61, 1, ❓)
        hop_1 = querydelete!(mb2, LinkLevelReplyAtHop, 61, 1, ❓)
        reply_2 = querydelete!(mb2, LinkLevelReply, 62, 1, ❓)
        hop_2 = querydelete!(mb1, LinkLevelReplyAtHop, 62, 1, ❓)

        @test all(!isnothing, (reply_1, hop_1, reply_2, hop_2))
        if all(!isnothing, (reply_1, hop_1, reply_2, hop_2))
            claimed_pairs = Set((
                (reply_1.tag[4], hop_1.tag[4]),
                (hop_2.tag[4], reply_2.tag[4]),
            ))
            @test claimed_pairs == Set(pair_slots)
        end
        @test isnothing(querydelete!(mb1, LinkLevelReply, 61, 1, ❓))
        @test isnothing(querydelete!(mb2, LinkLevelReply, 62, 1, ❓))

        for (slot_a, slot_b) in pair_slots
            @test isnothing(inventory_tag(
                net, 1, slot_a, 2, slot_b, EntanglementCounterpart
            ))
            @test isnothing(inventory_tag(
                net, 2, slot_b, 1, slot_a, EntanglementCounterpart
            ))
            @test isassigned(net[1][slot_a])
            @test isassigned(net[2][slot_b])
            @test QuantumSavory.stateof(net[1][slot_a]) ===
                QuantumSavory.stateof(net[2][slot_b])
        end
        @test all(!islocked(net[node][slot]) for node in 1:2 for slot in 1:5)
    end
end
