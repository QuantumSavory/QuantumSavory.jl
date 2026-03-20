using Test

global logging = Tuple[]
include("../../examples/piecemakerswitch/setup.jl")

@testset "Examples - piecemakerswitch" begin
    empty!(logging)

    sim = prepare_sim(3, CliffordRepr(), nothing, 1.0, 42, 1)
    run(sim)

    @test length(logging) == 1
    @test first(logging)[1] > 0
    @test 0.0 <= first(logging)[2] <= 1.0
end
