using Test

@testset "Examples - ASPEN-Net" begin
    include("../../examples/aspen_net/1_simple_run.jl")

    @test !isempty(consumer._log)
    @test all(!isassigned(net[node][slot]) for node in 1:3 for slot in 1:2)
    @test all(isnothing(query(net[node], EntanglementCounterpart, ❓, ❓, ❓)) for node in (1, 3))
end
