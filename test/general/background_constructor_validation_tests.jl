using Test
using QuantumSavory

@testset "Background constructor validation" begin
    cases = (
        (T1Decay, (:t1,)),
        (T2Dephasing, (:t2,)),
        (Depolarization, (:τ,)),
        (PauliNoise, (:τˣ, :τʸ, :τᶻ)),
        (AmplitudeDamping, (:τ,)),
        (T1T2Noise, (:t1, :t2)),
    )

    for (constructor, fields) in cases
        @test constructor() isa constructor
        for field in fields
            @test getfield(constructor(; NamedTuple{(field,)}((1,))...), field) == 1.0
            @test constructor(; NamedTuple{(field,)}((1.0,))...) isa constructor
            @test constructor(; NamedTuple{(field,)}((Inf,))...) isa constructor

            for invalid in (0.0, -1.0, NaN)
                exception = try
                    constructor(; NamedTuple{(field,)}((invalid,))...)
                    nothing
                catch err
                    err
                end
                @test exception isa DomainError
                @test occursin(string(field), exception.msg)
                if isnan(invalid)
                    @test isnan(exception.val)
                else
                    @test exception.val == invalid
                end
            end
        end
    end
end
