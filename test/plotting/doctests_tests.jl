using Test
using QuantumSavory
using Documenter

@testset "Doc tests" begin
    DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory; using QuantumSavory.CircuitZoo; using QuantumSavory.ProtocolZoo; using QuantumSavory.ProtocolZoo.MBQCEntanglementDistillation; using QuantumSavory.StatesZoo; using Graphs); recursive=true)
    doctestfilters = [r"(QuantumSavory\.|)"]
    doctest(QuantumSavory;
        doctestfilters,
        #fix=true
    )
end
