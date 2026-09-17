using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo

function test_domain_error(f, field::Symbol, value)
    exception = try
        f()
        nothing
    catch err
        err
    end
    @test exception isa DomainError
    @test occursin(string(field), exception.msg)
    if value isa AbstractFloat && isnan(value)
        @test isnan(exception.val)
    else
        @test exception.val == value
    end
end

@testset "ProtocolZoo execution-control constructor validation" begin
    net = RegisterNet([Register(2), Register(2)])

    @test EntanglerProt(net, 1, 2) isa EntanglerProt
    @test EntanglerProt(
        net,
        1,
        2;
        success_prob=1.0,
        attempt_time=0.0,
        local_busy_time_pre=0.0,
        local_busy_time_post=0.0,
        retry_lock_time=nothing,
        rounds=0,
        attempts=0,
        margin=0,
        hardmargin=0,
    ) isa EntanglerProt
    for invalid in (0.0, -1.0, 1.1, NaN)
        test_domain_error(
            () -> EntanglerProt(net, 1, 2; success_prob=invalid),
            :success_prob,
            invalid,
        )
    end
    for field in (
        :attempt_time,
        :local_busy_time_pre,
        :local_busy_time_post,
    )
        for invalid in (-1.0, NaN)
            test_domain_error(
                () -> EntanglerProt(
                    net,
                    1,
                    2;
                    NamedTuple{(field,)}((invalid,))...,
                ),
                field,
                invalid,
            )
        end
    end
    for invalid in (0.0, -1.0, NaN)
        test_domain_error(
            () -> EntanglerProt(net, 1, 2; retry_lock_time=invalid),
            :retry_lock_time,
            invalid,
        )
    end
    for field in (:rounds, :attempts)
        for invalid in (-2, NaN)
            test_domain_error(
                () -> EntanglerProt(
                    net,
                    1,
                    2;
                    NamedTuple{(field,)}((invalid,))...,
                ),
                field,
                invalid,
            )
        end
    end
    for field in (:margin, :hardmargin)
        for invalid in (-1, NaN)
            test_domain_error(
                () -> EntanglerProt(
                    net,
                    1,
                    2;
                    NamedTuple{(field,)}((invalid,))...,
                ),
                field,
                invalid,
            )
        end
    end

    @test SwapperProt(
        net,
        1;
        local_busy_time=0.0,
        retry_lock_time=nothing,
        rounds=0,
        agelimit=0.0,
        max_history_per_slot=0,
    ) isa SwapperProt
    for invalid in (-1.0, NaN)
        test_domain_error(
            () -> SwapperProt(net, 1; local_busy_time=invalid),
            :local_busy_time,
            invalid,
        )
    end
    for invalid in (0.0, -1.0, NaN)
        test_domain_error(
            () -> SwapperProt(net, 1; retry_lock_time=invalid),
            :retry_lock_time,
            invalid,
        )
    end
    for invalid in (-2, NaN)
        test_domain_error(
            () -> SwapperProt(net, 1; rounds=invalid),
            :rounds,
            invalid,
        )
    end
    for invalid in (-1.0, NaN)
        test_domain_error(
            () -> SwapperProt(net, 1; agelimit=invalid),
            :agelimit,
            invalid,
        )
    end
    for invalid in (-1, NaN)
        test_domain_error(
            () -> SwapperProt(net, 1; max_history_per_slot=invalid),
            :max_history_per_slot,
            invalid,
        )
    end

    @test EntanglementConsumer(net, 1, 2; period=nothing) isa EntanglementConsumer
    for invalid in (0.0, -1.0, NaN)
        test_domain_error(
            () -> EntanglementConsumer(net, 1, 2; period=invalid),
            :period,
            invalid,
        )
    end

    @test CutoffProt(
        net,
        1;
        period=nothing,
        retention_time=0.0,
        max_delete_per_slot=0,
    ) isa CutoffProt
    for invalid in (0.0, -1.0, NaN)
        test_domain_error(
            () -> CutoffProt(net, 1; period=invalid),
            :period,
            invalid,
        )
    end
    for invalid in (-1.0, NaN)
        test_domain_error(
            () -> CutoffProt(net, 1; retention_time=invalid),
            :retention_time,
            invalid,
        )
    end
    for invalid in (-1, NaN)
        test_domain_error(
            () -> CutoffProt(net, 1; max_delete_per_slot=invalid),
            :max_delete_per_slot,
            invalid,
        )
    end
end
