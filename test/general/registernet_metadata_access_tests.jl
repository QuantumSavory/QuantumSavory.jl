using Test
using QuantumSavory
using Graphs

@testset "Register and RegisterNet metadata access" begin
    regs = [Register(2), Register(2), Register(2)]
    net = RegisterNet(regs; name="line", names=["left", "middle", "right"])

    @test collect(vertices(net)) == [1, 2, 3]
    @test Set(Tuple.(edges(net))) == Set([(1, 2), (2, 3)])
    @test sort(neighbors(net, 2)) == [1, 3]
    @test nv(net) == 3
    @test ne(net) == 2
    @test size(adjacency_matrix(net)) == (3, 3)

    @test net[:] == regs
    @test net[2] === regs[2]
    @test net[:, 2] == [regs[1][2], regs[2][2], regs[3][2]]
    @test net[3, 1] == regs[3][1]

    @test length(regs[1]) == 2
    @test collect(regs[1]) == [regs[1][1], regs[1][2]]
    @test regs[1][[2, 1]] == [regs[1][2], regs[1][1]]

    net[1, :label] = "left"
    net[2, :label] = "middle"
    net[3, :label] = "right"
    @test net[:, :label] == ["left", "middle", "right"]

    token_counter = Ref(0)
    net[:, :token] = () -> begin
        token_counter[] += 1
        "token-$(token_counter[])"
    end
    @test net[:, :token] == ["token-1", "token-2", "token-3"]

    net[(:, :), :latency] = 2.5
    @test net[(1, 2), :latency] == 2.5
    @test net[(2, 1), :latency] == 2.5
    @test net[(:, :), :latency] == [2.5, 2.5]

    serial_counter = Ref(0)
    net[(:, :), :serial] = () -> begin
        serial_counter[] += 1
        serial_counter[]
    end
    @test sort(net[(:, :), :serial]) == [1, 2]

    edge12 = first(filter(e -> minmax(e.src, e.dst) == (1, 2), collect(edges(net))))
    net[edge12, :latency] = 4.0
    @test net[(1, 2), :latency] == 4.0

    net[1 => 2, :direction] = "east"
    net[2 => 1, :direction] = "west"
    net[2 => 3, :direction] = "east"
    @test net[1 => 2, :direction] == "east"
    @test net[2 => 1, :direction] == "west"
    @test sort(net[(:) => (:), :direction]) == ["east", "east"]
end
