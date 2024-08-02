using Documenter

function doctests()
    @testitem "Doc tests" tags=[:doctests] begin
        DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory; using QuantumSavory.CircuitZoo; using QuantumSavory.ProtocolZoo; using QuantumSavory.StatesZoo; using Graphs); recursive=true)
        doctest(QuantumSavory;
            #fix=true
        )
    end
end

doctests()
