using Test

@testset "Examples - firstgenrepeater_v2 3" begin
    include("../../examples/firstgenrepeater_v2/setup.jl")

    @testset "findqubitstopurify uses entanglement pair IDs" begin
        network = RegisterNet([Register(2), Register(2)])
        foreach(initialize!, network[1])
        foreach(initialize!, network[2])

        tag!(network[1][1], EntanglementCounterpart, 2, 1, 11)
        tag!(network[1][2], EntanglementCounterpart, 2, 2, 22)
        tag!(network[2][1], EntanglementCounterpart, 1, 1, 11)
        tag!(network[2][2], EntanglementCounterpart, 1, 2, 22)

        qa1, qa2, qb1, qb2 = findqubitstopurify(network, 1, 2)
        @test qa1.tag[2] == qa2.tag[2] == 2
        @test qb1.tag[2] == qb2.tag[2] == 1
        @test qa1.slot.idx == qb1.tag[3]
        @test qa2.slot.idx == qb2.tag[3]
        @test qb1.slot.idx == qa1.tag[3]
        @test qb2.slot.idx == qa2.tag[3]
        @test qa1.tag[4] == qb1.tag[4]
        @test qa2.tag[4] == qb2.tag[4]
        @test Set([qa1.tag[4], qa2.tag[4]]) == Set([11, 22])
    end

    @testset "findqubitstopurify rejects reciprocal pair ID mismatches" begin
        network = RegisterNet([Register(2), Register(2)])
        foreach(initialize!, network[1])
        foreach(initialize!, network[2])

        tag!(network[1][1], EntanglementCounterpart, 2, 1, 11)
        tag!(network[1][2], EntanglementCounterpart, 2, 2, 22)
        tag!(network[2][1], EntanglementCounterpart, 1, 1, 11)
        tag!(network[2][2], EntanglementCounterpart, 1, 2, 33)

        @test_throws AssertionError findqubitstopurify(network, 1, 2)
    end

    include("../../examples/firstgenrepeater_v2/3_purifier_example.jl")
end
