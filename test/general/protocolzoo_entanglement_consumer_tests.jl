using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, EntanglementConsumer
using Graphs
using ConcurrentSim
using ResumableFunctions
using Logging

struct CustomConsumerEntanglementTag end

@testset "ProtocolZoo Entanglement Consumer" begin

classical_delay = 1e-9 # avoid common zero-delay tracker races that show up as stale update logs
history_cap = typemax(Int) # this consumer stress test is not intended to exercise history garbage collection

if isinteractive()
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
    println("Logger set to debug")
end

@testset "custom entangler tags keep legacy consumer arity" begin
    net = RegisterNet([Register(1), Register(1)]; classical_delay)
    sim = get_time_tracker(net)

    @process EntanglerProt(sim, net, 1, 2; tag=CustomConsumerEntanglementTag, rounds=1, success_prob=1.0)()
    consumer = EntanglementConsumer(sim, net, 1, 2; tag=CustomConsumerEntanglementTag, period=0.1)
    @process consumer()

    run(sim, 1.0)

    @test length(consumer._log) == 1
    @test isnothing(query(net[1][1], CustomConsumerEntanglementTag, 2, 1))
    @test isnothing(query(net[2][1], CustomConsumerEntanglementTag, 1, 1))
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
        sprot = SwapperProt(sim, net, v; nodeL = <(v), nodeH = >(v), chooseL = argmin, chooseH = argmax, rounds = -1, max_history_per_slot = history_cap)
        @process sprot()
    end

    for v in vertices(net)
        etracker = EntanglementTracker(sim, net, v)
        @process etracker()
    end

    econ = EntanglementConsumer(sim, net, 1, n; period=1.0)
    @process econ()

    run(sim, 100)

    for log in econ._log
        @test log.obs1 ≈ 1.0
        @test log.obs2 ≈ 1.0
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
        sprot = SwapperProt(sim, net, v; nodeL = <(v), nodeH = >(v), chooseL = argmin, chooseH = argmax, rounds = -1, max_history_per_slot = history_cap)
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

    @test econ._log[1].t > 5 # the process should start after 5
    for log in econ._log
        @test log.obs1 ≈ 1.0
        @test log.obs2 ≈ 1.0
    end
end
end
