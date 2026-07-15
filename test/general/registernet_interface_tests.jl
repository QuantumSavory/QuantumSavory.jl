using Test
using QuantumSavory
using Graphs
using ConcurrentSim
using ResumableFunctions
using QuantumOpticsBase: Ket, Operator
using QuantumClifford: MixedDestabilizer

@testset "RegisterNet Interface" begin

##

r1 = Register(3)
r2 = Register(4)
r3 = Register(5)

net = RegisterNet([r1, r2, r3])

@test net[1,2] == r1[2]
@test net[2,3] == r2[3]

net[1,:label] = "lala"
@test net[1,:label] == "lala"
end

@testset "RegisterNet per-link delays" begin
    graph = path_graph(3)
    classical_delay(src, dst) = 10src + dst
    quantum_delay = (src, dst) -> src / 10 + dst / 100
    net = RegisterNet(
        graph,
        [Register(1), Register(1), Register(1)];
        classical_delay,
        quantum_delay,
    )

    @test channel(net, 1 => 2).delay == 12
    @test channel(net, 2 => 1).delay == 21
    @test channel(net, 2 => 3).delay == 23
    @test channel(net, 3 => 2).delay == 32
    @test qchannel(net, 1 => 2).queue.delay ≈ 0.12
    @test qchannel(net, 2 => 1).queue.delay ≈ 0.21
    @test qchannel(net, 2 => 3).queue.delay ≈ 0.23
    @test qchannel(net, 3 => 2).queue.delay ≈ 0.32

    scalar_net = RegisterNet(
        [Register(1), Register(1)];
        classical_delay=1.5,
        quantum_delay=2.5,
    )
    @test channel(scalar_net, 1 => 2).delay == 1.5
    @test channel(scalar_net, 2 => 1).delay == 1.5
    @test qchannel(scalar_net, 1 => 2).queue.delay == 2.5
    @test qchannel(scalar_net, 2 => 1).queue.delay == 2.5

    arrival_times = Float64[]
    @resumable function receive_one(sim, net, arrival_times)
        @yield onchange(messagebuffer(net, 1))
        push!(arrival_times, now(sim))
    end
    @process receive_one(get_time_tracker(net), net, arrival_times)
    put!(channel(net, 2 => 1), Tag(:directional_delay))
    run(get_time_tracker(net))
    @test arrival_times == [21.0]
end
