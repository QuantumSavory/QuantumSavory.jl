@testitem "Control Protocols" tags=[:controlplane] begin

using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions

using Graphs

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

adjm = [0 1 0 0 1 0 0 0
        1 0 1 0 0 0 0 0
        0 1 0 1 0 1 0 0
        0 0 1 0 0 0 1 1
        1 0 0 0 0 1 0 1
        0 0 1 0 1 0 1 0
        0 0 0 1 0 1 0 1
        0 0 0 1 1 0 1 0]
graph = SimpleGraph(adjm)

regsize = 20
net = RegisterNet(graph, [Register(regsize) for i in 1:8])
sim = get_time_tracker(net)

# controller
controller = Controller(sim, net, 6, zeros(8,8))
@process controller()

# RequestGenerator for the user pair (1,8)
req_gen = RequestGenerator(sim, net, 1, 8, 6)
@process req_gen()

# consumer
consumer = EntanglementConsumer(sim, net, 1, 8)
@process consumer()

# entanglement and request trackers, cutoff protocol
for v in 1:8
    etracker = EntanglementTracker(sim, net, v)
    rtracker = RequestTracker(sim, net, v)
    cutoff = CutoffProt(sim, net, v)
    @process etracker()
    @process rtracker()
    @process cutoff()
end

run(sim, 1000)

for i in 1:length(consumer.log)
    @test consumer.log[i][2] ≈ 1.0
    @test consumer.log[i][3] ≈ 1.0
end

#### Connection less controller

net = RegisterNet(graph, [Register(regsize) for i in 1:8])
sim = get_time_tracker(net)

# controller
controller = CLController(sim, net, 6)
@process controller()

# RequestGenerator for the user pair (1,8)
req_gen = RequestGenerator(sim, net, 1, 8, 6)
@process req_gen()

# consumer
consumer = EntanglementConsumer(sim, net, 1, 8)
@process consumer()

# entanglement and request trackers, cutoff protocol
for v in 1:8
    etracker = EntanglementTracker(sim, net, v)
    rtracker = RequestTracker(sim, net, v)
    cutoff = CutoffProt(sim, net, v)
    @process etracker()
    @process rtracker()
    @process cutoff()
end

run(sim, 1000)

for i in 1:length(consumer.log)
    @test consumer.log[i][2] ≈ 1.0
    @test consumer.log[i][3] ≈ 1.0
end

end