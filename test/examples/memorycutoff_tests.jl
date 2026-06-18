using Test

@testset "Examples - memorycutoff" begin
    old_test_run = get(ENV, "QS_TESTRUN", nothing)
    ENV["QS_TESTRUN"] = "true"
    try
        include("../../examples/memorycutoff/1_cutoff_sweep.jl")
    finally
        if isnothing(old_test_run)
            delete!(ENV, "QS_TESTRUN")
        else
            ENV["QS_TESTRUN"] = old_test_run
        end
    end

    @test length(results) == 2
    @test all(row -> row.retention_time > 0, results)
    @test all(row -> row.agelimit > 0, results)
    @test all(row -> row.delivered >= 0, results)
    @test all(row -> isnan(row.mean_zz) || -1.0 <= row.mean_zz <= 1.0, results)
    @test all(row -> isnan(row.mean_xx) || -1.0 <= row.mean_xx <= 1.0, results)
end
