using Aqua
using QuantumSavory

@test Test.detect_ambiguities(QuantumSavory) == Tuple{Method, Method}[]

Aqua.test_all(QuantumSavory,
    ambiguities=(QuantumSavory; recursive=false),
    piracies=(; treat_as_own=[QuantumSavory.Symbolic]),
    stale_deps=(; ignore=[:NetworkLayout]) # needed by package extension but not a condition of its loading
)

@test length(Aqua.Piracy.hunt(QuantumSavory)) == 6
