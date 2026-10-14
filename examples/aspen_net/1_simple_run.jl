using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions
using Graphs
using Random

Random.seed!(42)

# Sources 1 and 3 share a clock with central node 2. Each has only two slots.
net = RegisterNet(path_graph(3), [Register(2, QuantumOpticsRepr()) for _ in 1:3];
    quantum_delay=0.02, classical_delay=0.03)
sim = get_time_tracker(net)
schedule = AspenSchedule(;
    heralding_prob=0.5, coincidence_prob=0.95, attempt_time=0.001,
    period=1.0, rounds=200, arrival_timeout=0.1, coincidence_window=0.01,
    acknowledgement_timeout=0.2)
sources = [AspenSourceProt(net, node, 2; schedule, central_fraction=0.1) for node in (1, 3)]
central = AspenCentralProt(net, 2, 1, 3; schedule)

# A consumer frees successful memories before later rounds need them.
consumer = EntanglementConsumer(net, 1, 3; period=0.5)
for source in sources
    @process source()
end
@process central()
@process consumer()
run(sim, schedule.rounds * schedule.period)

show(stdout, MIME"text/plain"(), sources[1])
println()
show(stdout, MIME"text/plain"(), central)
println()
