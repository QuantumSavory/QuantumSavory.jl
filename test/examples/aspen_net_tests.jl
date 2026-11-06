using Test
using QuantumSavory.ProtocolZoo.AspenNet: Confirmation, TimeTag

@testset "Examples - ASPEN-Net" begin
    include("../../examples/aspen_net/1_simple_run.jl")

    periods = 1:div(stop_tick, repetitions)
    @test getproperty.(hub._log, :period) == periods
    @test getproperty.(hub._log, :t) == periods .* (repetitions * tick_duration) .+ delay
    @test any(row.success for row in hub._log)
    @test any(!row.success for row in hub._log)
    for (node, measurement) in zip((1, 3), measurements)
        @test !isempty(measurement._log)
        @test all(row.number in (0, 1) && row.t == row.period * repetitions * tick_duration
            for row in measurement._log)
        @test all(!isassigned(net[node], slot) for slot in 1:2)
        @test isnothing(query(net[node], TimeTag, ❓))
        for row in hub._log
            reply = querydelete!(messagebuffer(net, node), Confirmation, row.period, Int(row.success))
            @test !isnothing(reply)
        end
        @test isnothing(query(messagebuffer(net, node), Confirmation, ❓, ❓))
    end
end
