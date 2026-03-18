using Test
using QuantumSavory
using QuantumSavory.CircuitZoo
using QuantumSavory.CircuitZoo: AbstractCircuit, inputqubits
using InteractiveUtils

@testset "CIRCUITZOO_API Circuit Zoo API" begin

for T in subtypes(AbstractCircuit)
    circ = T()
    ms = methods(circ)
    @test length(ms) == 1 # this can be relaxed one day, but for now it can check we are not doing weird stuff
    m = first(ms)
    if hasmethod(inputqubits, Tuple{T}) # TODO should all of them have this method?
        @test m.isva || inputqubits(circ) == m.nargs-1
    end
end
end
