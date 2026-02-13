@testitem "ProtocolZoo BBM92 QKD" tags=[:protocolzoo_bbm92] begin
using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, SwapperProt, EntanglementTracker, BBM92Prot,
    sifted_key, qber_estimate, keyrate
using Graphs
using ConcurrentSim
using ResumableFunctions

if isinteractive()
    using Logging
    logger = ConsoleLogger(Logging.Warn; meta_formatter=(args...)->(:black,"",""))
    global_logger(logger)
end

# Test 1: Direct link (2 nodes, no swapping)
# With a perfect Bell pair and no noise, QBER should be 0.
for _ in 1:5
    regsize = 10
    net = RegisterNet([Register(regsize), Register(regsize)])
    sim = get_time_tracker(net)

    eprot = EntanglerProt(sim, net, 1, 2; rounds=-1, randomize=true, success_prob=1.0, attempt_time=0.001)
    @process eprot()

    bbm92 = BBM92Prot(sim, net, 1, 2; period=0.1)
    @process bbm92()

    run(sim, 50)

    @test length(bbm92._log) > 0

    # Sifted key: roughly half the measurements should have matching bases
    keyA, keyB = sifted_key(bbm92._log)
    n_sifted = length(keyA)
    n_total = length(bbm92._log)
    @test n_sifted > 0
    # Expected sifting ratio ≈ 0.5 (binomial, check within reasonable range)
    @test 0.2 < n_sifted / n_total < 0.8

    # For a noiseless Bell pair, QBER should be exactly 0
    @test qber_estimate(bbm92._log) == 0.0

    # Alice and Bob's key bits should match perfectly
    @test keyA == keyB

    # Key rate should be positive
    @test keyrate(bbm92._log) > 0.0
end

# Test 2: Repeater chain (3+ nodes with swapping)
for n in [3, 5, 8]
    regsize = 10
    net = RegisterNet([Register(regsize) for _ in 1:n])
    sim = get_time_tracker(net)

    for e in edges(net)
        eprot = EntanglerProt(sim, net, e.src, e.dst; rounds=-1, randomize=true, margin=5, hardmargin=3)
        @process eprot()
    end

    for v in 2:n-1
        sprot = SwapperProt(sim, net, v; nodeL = <(v), nodeH = >(v), chooseL = argmin, chooseH = argmax, rounds=-1)
        @process sprot()
    end

    for v in vertices(net)
        etracker = EntanglementTracker(sim, net, v)
        @process etracker()
    end

    bbm92 = BBM92Prot(sim, net, 1, n; period=1.0)
    @process bbm92()

    run(sim, 200)

    @test length(bbm92._log) > 0

    keyA, keyB = sifted_key(bbm92._log)
    @test length(keyA) > 0

    # For a perfect noiseless chain, QBER should still be 0
    @test qber_estimate(bbm92._log) == 0.0
    @test keyA == keyB
end

# Test 3: period=nothing (event-driven waiting)
regsize = 10
net = RegisterNet([Register(regsize), Register(regsize)])
sim = get_time_tracker(net)

eprot = EntanglerProt(sim, net, 1, 2; rounds=-1, randomize=true, success_prob=1.0, attempt_time=0.001)
@process eprot()

bbm92 = BBM92Prot(sim, net, 1, 2; period=nothing)
@process bbm92()

run(sim, 20)

@test length(bbm92._log) > 0
@test qber_estimate(bbm92._log) == 0.0

# Test 4: Helper function edge cases
@test isnan(qber_estimate(typeof(bbm92._log[1])[]))
@test keyrate(typeof(bbm92._log[1])[]) == 0.0
keyA_empty, keyB_empty = sifted_key(typeof(bbm92._log[1])[])
@test isempty(keyA_empty)
@test isempty(keyB_empty)

# Test 5: Verify permits_virtual_edge
@test QuantumSavory.ProtocolZoo.permits_virtual_edge(bbm92) == true

end
