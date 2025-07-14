@testitem "JET checks" tags=[:jet] begin
    using JET
    using Test
    using QuantumSavory

    rep = JET.report_package(QuantumSavory, target_defined_modules = true)
    @test length(JET.get_reports(rep)) <= 12
    @test_broken length(JET.get_reports(rep)) == 0
end
