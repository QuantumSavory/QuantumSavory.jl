using Test

@testset "Examples - bell memory explorer" begin
    include("../../examples/bell_memory_explorer/setup.jl")

    trace = bell_memory_trace(F = 1.0, T2 = 50.0, tmax = 100.0, samples = 9)
    @test length(trace.time) == 9
    @test trace.time[1] == 0.0
    @test trace.time[end] == 100.0
    @test isapprox(trace.xx[1], 1.0; atol = 1e-8)
    @test isapprox(trace.zz[1], 1.0; atol = 1e-8)
    @test all(isfinite, trace.fidelity)
    @test minimum(trace.fidelity) >= -1e-8
    @test maximum(trace.fidelity) <= 1.0 + 1e-8

    try
        include("../../examples/bell_memory_explorer/bell_memory_explorer.jl")
    finally
        if isdefined(@__MODULE__, :server)
            close(server)
            wait(server)
        end
    end
end
