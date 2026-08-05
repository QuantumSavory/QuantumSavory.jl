using Test
using QuantumSavory: @domain

@testset "@domain" begin
    function bounded(x)
        @domain 0 < x ≤ 1
        return x
    end

    @test bounded(0.5) == 0.5
    @test bounded(1.0) == 1.0
    exception = try
        bounded(1.1)
        nothing
    catch err
        err
    end
    @test exception isa DomainError
    @test exception.val == 1.1
    @test exception.msg == "x must obey `0 < x ≤ 1`"

    @test_throws ArgumentError macroexpand(@__MODULE__, :(@domain x < y))
end
