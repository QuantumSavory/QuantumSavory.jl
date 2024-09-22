@testitem "JET" tags=[:jet] begin
using JET
using DiffEqBase, Graphs, JumpProcesses, Makie, ResumableFunctions, ConcurrentSim, QuantumOptics, QuantumOpticsBase, QuantumClifford, Symbolics, WignerSymbols

rep = report_package("QuantumSavory";
    ignored_modules=(
        AnyFrameModule(DiffEqBase),
        AnyFrameModule(Graphs.LinAlg),
        AnyFrameModule(Graphs.SimpleGraphs),
        AnyFrameModule(JumpProcesses),
        AnyFrameModule(Makie),
        AnyFrameModule(Symbolics),
        AnyFrameModule(QuantumOptics),
        AnyFrameModule(QuantumOpticsBase),
        AnyFrameModule(QuantumClifford),
        AnyFrameModule(ResumableFunctions),
        AnyFrameModule(ConcurrentSim),
        AnyFrameModule(WignerSymbols),
        AnyFrameModule(SumTypes),
    ))

@show length(JET.get_reports(rep))
@show rep

@test length(JET.get_reports(rep)) <= 33
@test_broken length(JET.get_reports(rep)) == 0
end
