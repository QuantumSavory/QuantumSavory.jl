using QuantumSavory, JET, Makie, Graphs, ResumableFunctions, SimJulia, QuantumOpticsBase, QuantumClifford, Symbolics

rep = report_package("QuantumSavory";
    ignored_modules=(
        AnyFrameModule(Makie),
        AnyFrameModule(Graphs.LinAlg),
        AnyFrameModule(Graphs.SimpleGraphs),
        AnyFrameModule(Symbolics),
        AnyFrameModule(QuantumOpticsBase),
        AnyFrameModule(QuantumClifford),
        AnyFrameModule(ResumableFunctions),
        AnyFrameModule(SimJulia),
        ))

@show rep
@test_broken length(JET.get_reports(rep)) == 0
