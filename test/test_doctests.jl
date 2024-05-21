using Test
using Documenter
using QuantumSavory

function doctests()
    @testset "Doctests" begin
        DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory; using QuantumSavory.CircuitZoo; using QuantumSavory.ProtocolZoo; using QuantumSavory.StatesZoo; using Graphs); recursive=true)
        doctest(QuantumSavory;
            #fix=true
        )
    end
end

doctests()
