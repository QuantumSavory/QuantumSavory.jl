using Test

@testset "Examples - UUID entanglement tracking" begin
    include("../../examples/uuid_entanglement_tracking/setup.jl")

    uuid_result = run_uuid_tracking_demo()
    history_result = run_history_tracking_demo()

    @test uuid_result.xx ≈ 1.0
    @test uuid_result.zz ≈ 1.0
    @test history_result.xx ≈ 1.0
    @test history_result.zz ≈ 1.0
    @test uuid_result.left_tag.tag[2] == uuid_result.right_tag.tag[2] == 33
end
