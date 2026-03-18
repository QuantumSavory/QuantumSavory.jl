using JET
using Test
using QuantumSavory

@testset "JET JET checks" begin

    rep = JET.report_package(QuantumSavory; target_modules=(QuantumSavory,))
    println(rep)
    @test length(JET.get_reports(rep)) == 0
    #@test_broken length(JET.get_reports(rep)) == 0
end
