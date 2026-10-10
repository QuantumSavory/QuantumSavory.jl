using Test

@testset "Examples - bb84qkd 1" begin
    include("../../examples/bb84qkd/1_single_run.jl")

    @test stats_pristine.sifted > 200
    @test qber_pristine == 0.0
    @test stats_eve.sifted > 800
    @test abs(qber_eve - 0.25) < 0.06
end
