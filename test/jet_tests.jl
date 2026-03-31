# This file is included directly from `test/runtests.jl` for jet-only runs
# instead of being dispatched through `ParallelTestRunner`.
using JET
using Test
using QuantumSavory

@testset "JET checks" begin

    rep = JET.report_package(QuantumSavory; target_modules=(QuantumSavory,))
    println(rep)
    @test length(JET.get_reports(rep)) == 0
    #@test_broken length(JET.get_reports(rep)) == 0
end
