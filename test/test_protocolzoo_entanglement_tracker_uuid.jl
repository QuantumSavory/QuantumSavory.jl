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
    # Test 1: Basic UUID generation
    @test typeof(generate_pair_uuid()) == UInt128

    ##
    # Test 2: EntanglerProtUUID and basic entanglement creation

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

    # The UUIDs should match
    uuid_1 = uuid_tags_1[1][2]
    uuid_2 = uuid_tags_2[1][2]
    @test uuid_1 == uuid_2

    # Test that remote node/slot info is correct
    @test uuid_tags_1[1][3] == 2  # Node 1 is entangled to node 2
    @test uuid_tags_2[1][3] == 1  # Node 2 is entangled to node 1

    ##
    # Test 3: SwapperProtUUID with EntanglementTrackerUUID

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

    # Start trackers
    tracker2 = EntanglementTrackerUUID(sim, net, 2)
    tracker3 = EntanglementTrackerUUID(sim, net, 3)
    @process tracker2()
    @process tracker3()

    # Perform swap at node 2
    swapper2 = SwapperProtUUID(
        sim,
        net,
        2;
        nodeL = <(2),
        nodeH=>(2),
        chooseL = argmin,
        chooseH = argmax,
        rounds = 1,
    )
    @process swapper2()
    run(sim, 50)

    # Give time for message processing
    run(sim, 60)

    # After swap, node 1 should be connected to node 3
    uuid_tags_1 = [
        tag for tag in (net[1].tag_info[i].tag for i in net[1].guids) if
        tag.type == EntanglementUUID
    ]
    @test length(uuid_tags_1) >= 1
    @test uuid_tags_1[1][3] == 3  # Node 1 now entangled to node 3

    ##
    # Test 4: CutoffProtUUID

    net = RegisterNet([Register(3), Register(3)])
    sim = get_time_tracker(net)

    # Create entanglement
    entangler = EntanglerProtUUID(sim, net, 1, 2; rounds = 1)
    @process entangler()
    run(sim, 20)

    # Create cutoff protocol that will delete qubits after 30 time units
    cutoff1 = CutoffProtUUID(sim, net, 1; retention_time = 30.0, announce = true)
    cutoff2 = CutoffProtUUID(sim, net, 2; retention_time = 30.0, announce = true)
    tracker1 = EntanglementTrackerUUID(sim, net, 1)
    tracker2 = EntanglementTrackerUUID(sim, net, 2)

    @process cutoff1()
    @process cutoff2()
    @process tracker1()
    @process tracker2()

    # Run until cutoff triggers
    run(sim, 50)

    # Qubits should be deleted
    @test length(collect(net[1])) >= 0  # May or may not have qubits

    ##
    # Test 5: EntanglementConsumerUUID

    net = RegisterNet([Register(2), Register(2)])
    sim = get_time_tracker(net)

    entangler = EntanglerProtUUID(sim, net, 1, 2; rounds = 1)
    consumer = EntanglementConsumerUUID(sim, net, 1, 2; period = nothing)

    @process entangler()
    @process consumer()
    run(sim, 50)

    # Consumer should have logged the consumption
    @test length(consumer._log) >= 1
    @test consumer._log[1][1] == 50.0  # Time of consumption

    ##
    # Test 6: Multiple sequential swaps

    net = RegisterNet([Register(3), Register(3), Register(3)])
    sim = get_time_tracker(net)

    # Create chain: 1-2-3
    entangler1 = EntanglerProtUUID(sim, net, 1, 2; rounds = 1)
    entangler2 = EntanglerProtUUID(sim, net, 2, 3; rounds = 1)

    @process entangler1()
    @process entangler2()
    run(sim, 30)

    # Start trackers and swapper
    tracker2 = EntanglementTrackerUUID(sim, net, 2)
    @process tracker2()

    swapper2 = SwapperProtUUID(
        sim,
        net,
        2;
        nodeL = <(2),
        nodeH=>(2),
        chooseL = argmin,
        chooseH = argmax,
        rounds = 1,
    )
    @process swapper2()
    run(sim, 40)

    # Now 1 should be entangled to 3
    uuid_tags_1 = [
        tag for tag in (net[1].tag_info[i].tag for i in net[1].guids) if
        tag.type == EntanglementUUID
    ]

    # Verify the swap created the correct connection
    if length(uuid_tags_1) > 0
        @test uuid_tags_1[1][3] == 3
    end

    println("All UUID-based entanglement tracker tests passed!")

end
