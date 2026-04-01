using Test
using Graphs: complete_graph, star_graph
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo

const Switches = QuantumSavory.ProtocolZoo.Switches

@testset "ProtocolZoo Switch helper contracts" begin
    @testset "SymMatrix keeps symmetric access in sync" begin
        matrix = zeros(Int, 3, 3)
        symmetric = Switches.SymMatrix(matrix)

        symmetric[3, 1] = 7

        @test symmetric[1, 3] == 7
        @test symmetric[3, 1] == 7
        @test sum(symmetric) == 7
    end

    @testset "match_entangled_pattern picks the maximum backlog matching" begin
        backlog = [
            0 1 10 2
            1 0 2 7
            10 2 0 3
            2 7 3 0
        ]

        result = Switches.match_entangled_pattern(
            backlog,
            [1, 2, 3, 4],
            complete_graph(4),
            zeros(Int, 4, 4),
        )

        @test result.weight == 17
        @test Set(result.mate) == Set([(1, 3), (2, 4)])
    end

    @testset "promponas_bruteforce_choice returns useful assignments only" begin
        empty_backlog = zeros(Int, 3, 3)
        @test isnothing(Switches.promponas_bruteforce_choice(2, 3, empty_backlog, fill(0.5, 3)))

        backlog = fill(10, 5, 5)
        for i in axes(backlog, 1)
            backlog[i, i] = 0
        end
        eprobs = [0.6, 0.5, 0.9, 0.8, 0.7]

        assignment = Switches.promponas_bruteforce_choice(4, 5, backlog, eprobs)

        @test assignment == [1, 3, 4, 5]
    end

    @testset "switch backlog intake and matching stay consistent" begin
        graph = star_graph(4)
        net = RegisterNet(graph, [Register(3), Register(1), Register(1), Register(1)])
        switch = SimpleSwitchDiscreteProt(net, 1, 2:4, fill(1.0, 3); ticktock=2.0, rounds=1)
        reverseclientindex = Dict(2 => 1, 3 => 2, 4 => 3)

        put!(messagebuffer(net, 1), SwitchRequest(2, 4))
        put!(messagebuffer(net, 1), Tag(SwitchRequest(3, 4)))
        Switches._switch_read_backlog(switch, reverseclientindex)

        @test switch._backlog[1, 3] == 1
        @test switch._backlog[3, 1] == 1
        @test switch._backlog[2, 3] == 1
        @test switch._backlog[3, 2] == 1

        initialize!(net[1][1], X1)
        initialize!(net[1][2], X1)
        initialize!(net[1][3], X1)
        tag!(net[1][1], EntanglementCounterpart, 2, 1)
        tag!(net[1][2], EntanglementCounterpart, 3, 1)
        tag!(net[1][3], EntanglementCounterpart, 4, 1)

        match = Switches._switch_successful_entanglements_best_match(switch, reverseclientindex)

        normalized_match = Set((min(i, j), max(i, j)) for (i, j) in match)
        @test normalized_match == Set([(1, 3)])
    end

    @testset "synchronized switch cleanup deletes unused raw links on both ends" begin
        graph = star_graph(2)
        net = RegisterNet(graph, [Register(1), Register(1)])
        sim = get_time_tracker(net)
        switch = SimpleSwitchDiscreteProt(net, 1, [2], [1.0]; ticktock=1.0, rounds=1)

        initialize!((net[1][1], net[2][1]), (Z1 ⊗ Z1 + Z2 ⊗ Z2) / sqrt(2.0))
        tag!(net[1][1], EntanglementCounterpart, 2, 1)
        tag!(net[2][1], EntanglementCounterpart, 1, 1)

        @process Switches._SwitchSynchronizedDelete(switch)()
        run(sim, 1.1)

        @test !isassigned(net[1][1])
        @test !isassigned(net[2][1])
        @test isnothing(query(net[1][1], EntanglementCounterpart, 2, 1))
        @test isnothing(query(net[2][1], EntanglementCounterpart, 1, 1))
    end
end
