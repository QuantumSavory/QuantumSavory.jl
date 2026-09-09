using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, BBM92Prot, sifted_key, qber
using ConcurrentSim
using ResumableFunctions
using Graphs
using Random

function bbm92_run(; eavesdrop=false, rounds=-1, T=40.0, seed=42)
    Random.seed!(seed)
    net = RegisterNet([Register(4), Register(4)]; classical_delay=1e-9)
    sim = get_time_tracker(net)
    @process EntanglerProt(sim, net, 1, 2; rounds=-1, success_prob=1.0)()
    prot = BBM92Prot(sim, net, 1, 2; period=0.01, eavesdrop, rounds)
    @process prot()
    run(sim, T)
    return prot
end

@testset "ProtocolZoo BBM92" begin

@testset "noiseless pairs give a perfectly correlated sifted key" begin
    prot = bbm92_run()
    @test !isempty(prot._log)
    @test qber(prot) == 0.0
    sifted = [r for r in prot._log if r.basisA === r.basisB]
    @test all(r -> r.outcomeA == r.outcomeB, sifted)
    @test length(sifted_key(prot)) == length(sifted)
    @test all(in((1, -1)), sifted_key(prot))
end

@testset "bases are chosen independently, so about half the rounds sift" begin
    prot = bbm92_run()
    n = length(prot._log)
    @test 0.4 < length(sifted_key(prot)) / n < 0.6
    @test all(r -> r.basisA in (:Z, :X) && r.basisB in (:Z, :X), prot._log)
    @test all(r -> r.basisE === :none, prot._log)
end

@testset "intercept-resend leaves the textbook quarter of errors" begin
    prot = bbm92_run(eavesdrop=true)
    sifted = [r for r in prot._log if r.basisA === r.basisB]
    @test length(sifted) > 300
    @test 0.20 < qber(prot) < 0.30
    @test all(r -> r.basisE in (:Z, :X), prot._log)

    matched = [r for r in sifted if r.basisE === r.basisA]
    crossed = [r for r in sifted if r.basisE !== r.basisA]
    @test !isempty(matched) && !isempty(crossed)
    @test all(r -> r.outcomeA == r.outcomeB, matched)
    @test 0.4 < count(r -> r.outcomeA != r.outcomeB, crossed) / length(crossed) < 0.6
end

@testset "the round budget is respected" begin
    prot = bbm92_run(rounds=7)
    @test length(prot._log) == 7
end

@testset "qber is NaN before anything has been sifted" begin
    net = RegisterNet([Register(1), Register(1)])
    prot = BBM92Prot(get_time_tracker(net), net, 1, 2)
    @test isnan(qber(prot))
    @test isempty(sifted_key(prot))
end

end
