using Revise
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo:
    EntanglementUUID, EntanglementUpdateUUID, EntanglementDeleteUUID, generate_pair_uuid
using Graphs

@testitem "ProtocolZoo Entanglement Tracker UUID" tags=[
    :protocolzoo_entanglement_tracker_uuid,
] begin

    if isinteractive()
        using Logging
        logger = ConsoleLogger(Logging.Debug; meta_formatter = (args...)->(:black, "", ""))
        global_logger(logger)
        println("Logger set to debug")
    end

    ##

    # Test basic UUID generation
    @test typeof(generate_pair_uuid()) == UInt128

    # Test EntanglerProtUUID and basic entanglement

    net = RegisterNet([Register(3), Register(4), Register(2), Register(3)])
    sim = get_time_tracker(net)

    entangler1 = EntanglerProtUUID(sim, net, 1, 2; rounds = 1)
    @process entangler1()
    run(sim, 20)

    # Check that EntanglementUUID tags were created
    uuid_tags_1 = [
        tag for tag in (net[1].tag_info[i].tag for i in net[1].guids) if
        tag.type == EntanglementUUID
    ]
    uuid_tags_2 = [
        tag for tag in (net[2].tag_info[i].tag for i in net[2].guids) if
        tag.type == EntanglementUUID
    ]

    @test length(uuid_tags_1) == 1
    @test length(uuid_tags_2) == 1

    # The UUIDs should match and point to each other's remote node
    uuid_1 = uuid_tags_1[1][2]  # Extract UUID from tag
    uuid_2 = uuid_tags_2[1][2]
    @test uuid_1 == uuid_2  # Same pair should have same UUID

    # Test that remote node/slot info is correct
    @test uuid_tags_1[1][3] == 2  # Node 1 is entangled to node 2
    @test uuid_tags_2[1][3] == 1  # Node 2 is entangled to node 1

    ##

    # Test with SwapperProtUUID and EntanglementTrackerUUID

    net = RegisterNet([Register(3), Register(4), Register(2), Register(3)])
    sim = get_time_tracker(net)

    # Create entanglement between nodes 1-2 and 2-3
    entangler1 = EntanglerProtUUID(sim, net, 1, 2; rounds = 1)
    @process entangler1()
    run(sim, 20)

    entangler2 = EntanglerProtUUID(sim, net, 2, 3; rounds = 1)
    @process entangler2()
    run(sim, 30)

    # Create entanglement between nodes 4-3
    entangler3 = EntanglerProtUUID(sim, net, 4, 3; rounds = 1)
    @process entangler3()
    run(sim, 40)

    # Now start the trackers
    tracker2 = EntanglementTrackerUUID(sim, net, 2)
    tracker3 = EntanglementTrackerUUID(sim, net, 3)
    @process tracker2()
    @process tracker3()

    # Perform a swap at node 2 (connecting 1-2 and 2-3 into 1-3)
    swapper2 = SwapperProtUUID(
        sim,
        net,
        2;
        nodeL = <(2),
        nodeH = >(2),
        chooseL = argmin,
        chooseH = argmax,
        rounds = 1,
    )
    @process swapper2()
    run(sim, 50)

    # After swap, node 2 should have the connection updated from 1 to 3
    # The tracker should have processed the update messages

    # Give time for message processing
    run(sim, 60)

    # Check that the swap was successful
    # Node 1 should still have the same UUID but now pointing to node 3
    uuid_tags_1 = [
        tag for tag in (net[1].tag_info[i].tag for i in net[1].guids) if
        tag.type == EntanglementUUID
    ]
    @test length(uuid_tags_1) == 1
    @test uuid_tags_1[1][3] == 3  # Node 1 now entangled to node 3 (after swap)

    # Node 3 should have a UUID tag pointing to node 1
    uuid_tags_3 = [
        tag for tag in (net[3].tag_info[i].tag for i in net[3].guids) if
        tag.type == EntanglementUUID
    ]
    uuid_from_3 = [tag for tag in uuid_tags_3 if tag[3] == 1]  # Find tag pointing to node 1
    @test length(uuid_from_3) >= 1
end
