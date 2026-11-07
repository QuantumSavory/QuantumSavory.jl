using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo.AspenNet: Source, LocalMeasurement, Hub, Start
using Random

Random.seed!(42)

# End node 1 -- hub 2 -- end node 3; all links have the same delay.
delay = 2.0
net = RegisterNet(path_graph(3), [Register(fill(Qumode(), 2), fill(QuantumOpticsRepr(cutoff=4), 2)) for _ in 1:3];
    classical_delay=delay, quantum_delay=delay)
sim = get_time_tracker(net)
tick_duration, repetitions = 1.0, 100
stop_tick = 1000 * repetitions

sources = [Source(net, node, 2; tick_duration, repetitions,
    heralding_probability=0.1, reflectivity=0.01, memories=[1, 2]) for node in (1, 3)]
measurements = [LocalMeasurement(net, node) for node in (1, 3)]
hub = Hub(net, 2, (1, 3); tick_duration, repetitions)
for protocol in (sources..., measurements..., hub)
    Process(protocol)
end

# Commands use integer ticks. Each source runs the complete periods in (0, stop_tick].
for node in (1, 3)
    put!(messagebuffer(net, node), Tag(Start(0, stop_tick)))
end
run(sim, stop_tick * tick_duration + 2delay + 0.1)

display(hub)
foreach(display, measurements)
