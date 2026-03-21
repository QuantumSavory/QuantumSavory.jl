using Test
using Aqua
using QuantumOpticsBase
using QuantumSavory
using Gabs

@testset "Aqua" begin

@test Test.detect_ambiguities(QuantumSavory) == Tuple{Method, Method}[]

Aqua.test_all(QuantumSavory,
    ambiguities=(QuantumSavory; recursive=false),
    piracies=(; treat_as_own=[QuantumSavory.Symbolic, QuantumOpticsBase.Ket, QuantumOpticsBase.Operator, Gabs.GaussianChannel, Gabs.GaussianState, Gabs.GaussianUnitary]),
    stale_deps=(; ignore=[:NetworkLayout]) # needed by package extension but not a condition of its loading
)

@test length(Aqua.Piracy.hunt(QuantumSavory)) == 12 # TODO upstream the sources of piracies

end
