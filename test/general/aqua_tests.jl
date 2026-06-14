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
    persistent_tasks=(; tmax=30),
    stale_deps=(; ignore=[:NetworkLayout]) # needed by package extension but not a condition of its loading
)

@test length(Aqua.Piracy.hunt(QuantumSavory)) == 8 # TODO upstream the sources of piracies

end
