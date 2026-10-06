using Test

@testset "Examples - ASPEN-Net distribution" begin
    include("../../examples/aspen_net/1_entanglement_distribution.jl")

    @test length(aspen._log) == aspen.rounds
    @test all(row -> row.outcome in (:success, :failure), aspen._log)
    @test any(row -> row.outcome == :failure, aspen._log)
    @test count(row -> row.outcome == :success, aspen._log) == length(consumer._log) > 0
    @test all(row -> row.start ≈ (row.round - 1) * aspen.period, aspen._log)
    @test all(row -> row.complete ≈ row.herald + 0.002, aspen._log)
    @test !isassigned(net[1][1]) && !isassigned(net[3][1])
    @test isnothing(query(net[1], EntanglementCounterpart, ❓, ❓, ❓))
    @test isnothing(query(net[3], EntanglementCounterpart, ❓, ❓, ❓))
end
