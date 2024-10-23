
using Revise
using QuantumSavory
using ResumableFunctions
using ConcurrentSim
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX, EntanglementUpdateZ
using Graphs
using Test
using Random
using Logging

##

peekalltags(node) = vcat([QuantumSavory.peektags(node[i]) for i in 1:length(node)]...) # I use this inside some library code by accessing it through the `Main` module -- it is a neat hack for interactive debugging

##

#global_logger(ConsoleLogger(stderr, Logging.Debug))
global_logger(ConsoleLogger(stderr, Logging.Info))

##

n = 3
regsize = 10
net = RegisterNet([Register(regsize) for j in 1:n])
sim = get_time_tracker(net)

for e in edges(net)
    eprot = EntanglerProt(sim, net, e.src, e.dst; success_prob=1.0, rounds=1, randomize=true, margin=5, hardmargin=3)
    @process eprot()
end

for v in 2:n-1
    sprot = SwapperProt(sim, net, v; nodeL = <(v), nodeH = >(v), chooseL = argmin, chooseH = argmax, rounds =1, retry_lock_time=nothing)
    @process sprot()
end

for v in vertices(net)
    etracker = EntanglementTracker(sim, net, v)
    @process etracker()
end

econ = EntanglementConsumer(sim, net, 1, n; period=0.1)
@process econ()

run(sim, 100)

econ.log

##

using CairoMakie
registernetplot(net)
