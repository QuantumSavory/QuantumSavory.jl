using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer
using Graphs
using ConcurrentSim
using Test

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

for i in 1:30, n in 3:30

    net = RegisterNet([Register(10) for j in 1:n])
    sim = get_time_tracker(net)

    for e in edges(net)
        eprot = EntanglerProt(sim, net, e.src, e.dst; rounds=-1, randomize=true)
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

    econ = EntanglementConsumer(sim, net, 1, n, [], 1.0)
    @process econ()

    run(sim, 100)


    for i in 1:100
        if !isnothing(econ.log[i][2])
            @test econ.log[i][2] ≈ 1.0
            @test econ.log[i][3] ≈ 1.0
        end
    end

end
# @test length([econ.log[i] for i in 1:400 if !isnothing(econ.log[i][2])]) > 300
# length([net[2].tags[i][end] for i in 1:100 if net[2].tags[i][end][2]==4]) # almost all slots connected to either 3, 4 or 5, so no room for swaps
# [net[2].tags[i][end] for i in 1:100]
