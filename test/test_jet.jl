using Test
using QuantumSavory, JET
using DiffEqBase, Graphs, JumpProcesses, Makie, ResumableFunctions, ConcurrentSim, QuantumOptics, QuantumOpticsBase, QuantumClifford, Symbolics, WignerSymbols, GraphsMatching, JuMP, SumTypes

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
        AnyFrameModule(GraphsMatching),
        AnyFrameModule(JuMP.Containers),
        AnyFrameModule(SumTypes),
    ))

@show length(JET.get_reports(rep))
@show rep

@test length(JET.get_reports(rep)) <= 33
@test_broken length(JET.get_reports(rep)) == 0
