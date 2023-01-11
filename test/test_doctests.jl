using Documenter, QuantumSavory

function doctests()
    @testset "Doctests" begin
        DocMeta.setdocmeta!(QuantumSavory, :DocTestSetup, :(using QuantumSavory); recursive=true)
        doctest(QuantumSavory)
    end
end

doctests()
