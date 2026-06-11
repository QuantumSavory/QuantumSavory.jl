using Test
using Logging
using ConcurrentSim

@testset "Piecemaker switch clears consumed counterpart tags" begin
    include("../../examples/piecemakerswitch/setup.jl")

    switch = Register([Qubit(), Qubit()], [CliffordRepr(), CliffordRepr()], [nothing, nothing])
    client = Register([Qubit()], [CliffordRepr()], [nothing])
    net = RegisterNet(star_graph(2), [switch, client])
    sim = get_time_tracker(net)
    logging = []

    @process PiecemakerProt(sim, 1, net, 1.0, 2, logging)

    @test_logs min_level=Logging.Error begin
        run(sim)
    end

    @test isempty(queryall(net[2][1], EntanglementCounterpart, ❓, ❓))
end
