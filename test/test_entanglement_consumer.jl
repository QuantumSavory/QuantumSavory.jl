using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer
using Graphs
using ConcurrentSim
using Test

# using Logging
# logger = ConsoleLogger(Logging.Debug; meta_formatter=(args...)->(:black,"",""))
# global_logger(logger)

n = 3

net = RegisterNet([Register(4) for j in 1:n])
sim = get_time_tracker(net)

for e in edges(net)
    eprot = EntanglerProt(sim, net, e.src, e.dst; rounds=-1)
    @process eprot()
end

for v in 2:n-1
    sprot = SwapperProt(sim, net, v; rounds=-1)
    @process sprot()
end

for v in vertices(net)
    etracker = EntanglementTracker(sim, net, v)
    @process etracker()
end

econ = EntanglementConsumer(sim, net, 1, 3, [], 1.0)
@process econ()

run(sim, 400)


@test length([econ.log[i] for i in 1:400 if !isnothing(econ.log[i][2])]) > 100