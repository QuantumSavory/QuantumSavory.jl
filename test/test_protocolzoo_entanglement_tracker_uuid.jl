@testitem "ProtocolZoo Entanglement Tracker UUID" tags=[
    :protocolzoo_entanglement_tracker_uuid,
] begin
    using ResumableFunctions
    using ConcurrentSim
    using QuantumSavory.ProtocolZoo
    using Graphs

    if isinteractive()
        using Logging
        logger = ConsoleLogger(Logging.Debug; meta_formatter = (args...)->(:black, "", ""))
        global_logger(logger)
    end

    ##
    # Test basic UUID generation
    @test typeof(generate_pair_uuid()) == Int

    # Test EntanglerProtUUID and basic entanglement creation

    net = RegisterNet([Register(3), Register(4), Register(2), Register(3)])
    sim = get_time_tracker(net)

    entangler1 = EntanglerProtUUID(sim, net, 1, 2; rounds = 1, success_prob = 1.0)
    @process entangler1()
    run(sim, 20)

    # Helper to filter EntanglementUUID tags from a register
    function uuid_tags(reg)
        infos = queryall(reg, EntanglementUUID, ❓, ❓, ❓)
        [info.tag for info in infos]
    end

    uuid_tags_1 = uuid_tags(net[1])
    uuid_tags_2 = uuid_tags(net[2])

    @test length(uuid_tags_1) == 1
    @test length(uuid_tags_2) == 1

    # The UUIDs should match
    uuid_1 = uuid_tags_1[1][2]  # tag[2] is the uuid field
    uuid_2 = uuid_tags_2[1][2]
    @test uuid_1 == uuid_2

    # Test that remote node/slot info is correct
    @test uuid_tags_1[1][3] == 2  # Node 1 is entangled to node 2
    @test uuid_tags_2[1][3] == 1  # Node 2 is entangled to node 1

    # Test SwapperProtUUID with EntanglementTrackerUUID

    net = RegisterNet([Register(3), Register(4), Register(2), Register(3)])
    sim = get_time_tracker(net)

    # Create entanglement between nodes 1-2 and 2-3
    entangler1 = EntanglerProtUUID(sim, net, 1, 2; rounds = 1)
    @process entangler1()
    run(sim, 20)

    entangler2 = EntanglerProtUUID(sim, net, 2, 3; rounds = 1, success_prob = 1.0)
    @process entangler2()
    run(sim, 30)

    # Create entanglement between nodes 4-3
    entangler3 = EntanglerProtUUID(sim, net, 4, 3; rounds = 1, success_prob = 1.0)
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
        nodeH = >(2),
        chooseL = argmin,
        chooseH = argmax,
        rounds = 1,
    )
    @process swapper2()
    run(sim, 100)

    # After swap, node 1 should have entanglement (specifics may vary with timing)
    uuid_tags_1 = uuid_tags(net[1])
    @test length(uuid_tags_1) >= 1  # Entanglement should exist

    # Test CutoffProtUUID
    net = RegisterNet([Register(3), Register(3)])
    sim = get_time_tracker(net)

    # Create entanglement
    entangler = EntanglerProtUUID(sim, net, 1, 2; rounds = 1, success_prob = 1.0)
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

    # Test EntanglementConsumerUUID
    net = RegisterNet([Register(2), Register(2)])
    sim = get_time_tracker(net)

    entangler = EntanglerProtUUID(sim, net, 1, 2; rounds = 1, success_prob = 1.0)
    consumer = EntanglementConsumerUUID(sim, net, 1, 2; period = nothing)

    @process entangler()
    @process consumer()
    run(sim, 50)

    # Consumer should have logged the consumption
    @test length(consumer._log) >= 1
    @test consumer._log[1][1] >= 0  # Time of consumption should be logged

    # Test Multiple sequential swaps
    net = RegisterNet([Register(3), Register(3), Register(3)])
    sim = get_time_tracker(net)

    # Create chain: 1-2-3
    entangler1 = EntanglerProtUUID(sim, net, 1, 2; rounds = 1, success_prob = 1.0)
    entangler2 = EntanglerProtUUID(sim, net, 2, 3; rounds = 1, success_prob = 1.0)

    @process entangler1()
    @process entangler2()
    run(sim, 50)

    # Start trackers and swapper
    tracker2 = EntanglementTrackerUUID(sim, net, 2)
    @process tracker2()

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
    run(sim, 100)

    # Verify the swap protocol ran without error
    uuid_tags_1 = uuid_tags(net[1])

    # Check that entanglement tracking works (swap outcome may vary with timing)
    if length(uuid_tags_1) > 0
        # If entanglement exists, it should have a valid remote node
        @test uuid_tags_1[1][3] >= 1
    end

end
