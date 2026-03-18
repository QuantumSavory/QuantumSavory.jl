@testitem "ProtocolZoo CutoffProt" tags=[:protocolzoo_cutoffprot] begin
using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo

using ConcurrentSim
using ResumableFunctions

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

net = RegisterNet([Register(1), Register(1)])
sim = get_time_tracker(net)
initialize!((net[1][1], net[2][1]), (Z1⊗Z1+Z2⊗Z2)/(sqrt(2.0)))
tag!(net[1][1], EntanglementCounterpart, 2, 1)
tag!(net[2][1], EntanglementCounterpart, 1, 1)

cprot = CutoffProt(sim, net, 1; retention_time=3.0)
@process cprot()

run(sim, 2.0)
@test isassigned(net[1][1])
@test isassigned(net[2][1])

run(sim, 6.0)
@test !isassigned(net[1][1])
@test isassigned(net[2][1])

# test for period=nothing
net = RegisterNet([Register(2), Register(1)])
sim = get_time_tracker(net)
initialize!((net[1][1], net[2][1]), (Z1⊗Z1+Z2⊗Z2)/(sqrt(2.0)))
tag!(net[1][1], EntanglementCounterpart, 2, 1)
tag!(net[2][1], EntanglementCounterpart, 1, 1)

cprot1 = CutoffProt(sim, net, 1; period=nothing, retention_time=3.0)
cprot2 = CutoffProt(sim, net, 2; period=0.1, retention_time=3.0)
@process cprot1()
@process cprot2()

@resumable function wait_and_tag(sim)
    @yield timeout(sim, 5)
    tag!(net[1][2], Int)
end

@process wait_and_tag(sim)

run(sim, 2.0)
@test isassigned(net[1][1])
@test isassigned(net[2][1])

run(sim, 4.0)
@test isassigned(net[1][1])
@test !isassigned(net[2][1])

run(sim, 6.0)
@test !isassigned(net[1][1])
@test !isassigned(net[2][1])

end