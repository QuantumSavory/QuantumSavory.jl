using ResumableFunctions
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using Graphs
using Test
using Logging

@testset "ProtocolZoo Switch - SimpleSwitchDiscreteProt" begin
    if isinteractive()
        logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black, "", ""))
        global_logger(logger)
        println("Logger set to debug")
    end

    n = 5 # number of clients
    m = n - 2 # memory slots in switch
    graph = star_graph(n + 1) # index 1 corresponds to the switch
    switch_reg = Register(m)
    node_regs = [Register(1) for _ in 1:n]
    net = RegisterNet(graph, [switch_reg, node_regs...])
    sim = get_time_tracker(net)
    switch = SimpleSwitchDiscreteProt(net, 1, 2:n+1, fill(0.5, n))
    c = rand(1:6)
    if c == 1 # a silly way to try out all three APIs
        put!(net[1], SwitchRequest(2, 3))
    elseif c == 2
        put!(net[1], Tag(SwitchRequest(2, 3)))
    elseif c == 3
        put!(messagebuffer(net, 1), SwitchRequest(2, 3))
    elseif c == 4
        put!(messagebuffer(net[1]), Tag(SwitchRequest(2, 3)))
    elseif c == 5
        put!(channel(net, 2=>1), SwitchRequest(2, 3))
    elseif c == 6
        put!(channel(net, 2=>1), Tag(SwitchRequest(2, 3)))
    end
    @process switch()
    run(sim, 30)
    res = query(net[2], EntanglementCounterpart, W, W, W)

    # We are not running an EntanglementTracker, so Pauli corrections are not applied.
    @test isapprox(abs(observable([res.slot, net[3][res.tag[3]]], tensor(X, X))), 1.0)
    @test isapprox(abs(observable([res.slot, net[3][res.tag[3]]], tensor(Z, Z))), 1.0)
end

@testset "ProtocolZoo Switch - SwitchRequesterProt emits requests" begin
    net = RegisterNet(star_graph(3), [Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    requester = SwitchRequesterProt(net, 1, 2, 3; request_interval=0.25, rounds=3)

    @process requester()
    run(sim, 1.0)

    mb = messagebuffer(net, 1)
    @test !isnothing(querydelete!(mb, SwitchRequest, 2, 3))
    @test !isnothing(querydelete!(mb, SwitchRequest, 2, 3))
    @test !isnothing(querydelete!(mb, SwitchRequest, 2, 3))
    @test isnothing(querydelete!(mb, SwitchRequest, 2, 3))
end

@testset "ProtocolZoo Switch - SwitchRequesterProt drives switch scheduling" begin
    net = RegisterNet(star_graph(3), [Register(2), Register(1), Register(1)])
    sim = get_time_tracker(net)

    switch = SimpleSwitchDiscreteProt(net, 1, [2, 3], [1.0, 1.0]; ticktock=0.5, rounds=3)
    requester = SwitchRequesterProt(net, 1, 2, 3; request_interval=0.1, rounds=1)

    @process EntanglementTracker(net, 2)()
    @process EntanglementTracker(net, 3)()
    @process requester()
    @process switch()

    run(sim, 3.0)

    res = query(net[2], EntanglementCounterpart, 3, 1, W)
    @test !isnothing(res)
    pair_id = res.tag[4]
    @test !isnothing(query(net[3], EntanglementCounterpart, 2, 1, pair_id))
    @test isapprox(abs(observable((res.slot, net[3][1]), tensor(X, X))), 1.0)
    @test isapprox(abs(observable((res.slot, net[3][1]), tensor(Z, Z))), 1.0)
end
