using Revise
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using Graphs
using Test

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

@testset "SimpleSwitchDiscreteProt" begin
    n = 5 # number of clients
    m = n-2 # memory slots in switch
    graph = star_graph(n+1) # index 1 corresponds to the switch
    switch_reg = Register(m)
    node_regs = [Register(1) for _ in 1:n]
    net = RegisterNet(graph, [switch_reg, node_regs...])
    sim = get_time_tracker(net)
    switch = SimpleSwitchDiscreteProt(net, 1, 2:n+1, fill(0.5, n))
    #tag!(net[1], SwitchRequest(2,3)) # TODO this interface should be permitted
    #put!(channel(net, 2=>1), SwitchRequest(2,3)) # TODO this interface should be permitted
    put!(channel(net, 2=>1), Tag(SwitchRequest(2,3)))
    @process switch()
    run(sim, 30)
    res = query(net[2], EntanglementCounterpart, ❓, ❓)
    @test abs(observable([res.slot, net[3][res.tag[3]]], X⊗X)) ≈ 1.0 # we are not running an EntanglementTracker so Pauli corrections are not applied
    @test abs(observable([res.slot, net[3][res.tag[3]]], Z⊗Z)) ≈ 1.0 # we are not running an EntanglementTracker so Pauli corrections are not applied
end
