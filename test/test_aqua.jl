@testitem "Aqua" tags=[:aqua] begin
using Aqua

if get(ENV,"JET_TEST","")=="true"
# JET generates new methods with ambiguities
else

@test Test.detect_ambiguities(QuantumSavory) == Tuple{Method, Method}[]

Aqua.test_all(QuantumSavory,
    ambiguities=(QuantumSavory; recursive=false),
    piracies=(; treat_as_own=[QuantumSavory.Symbolic]),
    stale_deps=(; ignore=[:NetworkLayout]) # needed by package extension but not a condition of its loading
)

@test length(Aqua.Piracy.hunt(QuantumSavory)) == 6
end
