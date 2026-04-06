using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer
using Graphs
using ConcurrentSim
using ResumableFunctions
using Logging

@testset "ProtocolZoo Entanglement Consumer" begin

classical_delay = 1e-9 # avoid common zero-delay tracker races that show up as stale update logs

if isinteractive()
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end


for n in 3:30
    regsize = 10
    net = RegisterNet([Register(regsize) for j in 1:n]; classical_delay)
    sim = get_time_tracker(net)

    for e in edges(net)
        eprot = EntanglerProt(sim, net, e.src, e.dst; rounds=-1, randomize=true, margin=5, hardmargin=3)
        @process eprot()
    end

    for v in 2:n-1
        sprot = SwapperProt(sim, net, v; nodeL = <(v), nodeH = >(v), chooseL = argmin, chooseH = argmax, rounds = -1)
        @process sprot()
    end

    for v in vertices(net)
        etracker = EntanglementTracker(sim, net, v)
        @process etracker()
    end

    econ = EntanglementConsumer(sim, net, 1, n; period=1.0)
    @process econ()

    run(sim, 100)

    for i in eachindex(econ._log.time)
        @test econ._log.obs1[i] ≈ 1.0
        @test econ._log.obs2[i] ≈ 1.0
    end
end

# test for period=nothing

@resumable function delayedProts(sim, net, n)
    @yield timeout(sim, 5)
    for e in edges(net)
        eprot = EntanglerProt(sim, net, e.src, e.dst; rounds=-1, randomize=true, margin=5, hardmargin=3)
        @process eprot()
    end

    for v in 2:n-1
        sprot = SwapperProt(sim, net, v; nodeL = <(v), nodeH = >(v), chooseL = argmin, chooseH = argmax, rounds = -1)
        @process sprot()
    end

    for v in vertices(net)
        etracker = EntanglementTracker(sim, net, v)
        @process etracker()
    end
end

for n in 3:30
    regsize = 10
    net = RegisterNet([Register(regsize) for j in 1:n]; classical_delay)
    sim = get_time_tracker(net)

    econ = EntanglementConsumer(sim, net, 1, n; period=nothing)
    @process econ()
    @process delayedProts(sim, net, n)

    run(sim, 100)

    @test econ._log.time[1] > 0 # the process should start after 5
    for i in eachindex(econ._log.time)
        @test econ._log.obs1[i] ≈ 1.0
        @test econ._log.obs2[i] ≈ 1.0
    end
end
end
