using Test
using Aqua
using QuantumOpticsBase
using QuantumSavory
using Gabs
using WorkerUtilities

@testset "Aqua" begin

function filtered_detect_ambiguities(ignore_packages::Vector{Module})
    ambs = Test.detect_ambiguities(QuantumSavory)
    filtered = filter(ambs) do (m1, m2)
        !(m1.module in ignore_packages) &&
        !(m2.module in ignore_packages)
    end

    return isempty(filtered)
end

@test filtered_detect_ambiguities([WorkerUtilities])

Aqua.test_all(QuantumSavory,
    ambiguities=(QuantumSavory; recursive=false),
    piracies=(; treat_as_own=[QuantumSavory.Symbolic, QuantumOpticsBase.Ket, QuantumOpticsBase.Operator, Gabs.GaussianChannel, Gabs.GaussianState, Gabs.GaussianUnitary]),
    stale_deps=(; ignore=[:NetworkLayout]) # needed by package extension but not a condition of its loading
)

@test length(Aqua.Piracy.hunt(QuantumSavory)) == 8 # TODO upstream the sources of piracies

end
