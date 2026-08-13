using Test

@testset "Examples - MySwapperProt tutorial" begin
    include("../../examples/myswapper_tutorial/my_swapper_prot.jl")

    @test !isnothing(alice_final)
    @test !isnothing(charlie_final)
    @test alice_final.tag[2] == 3
    @test charlie_final.tag[2] == 1
    @test alice_final.slot.idx == charlie_final.tag[3]
    @test charlie_final.slot.idx == alice_final.tag[3]
    @test alice_final.tag[4] == charlie_final.tag[4]
end
