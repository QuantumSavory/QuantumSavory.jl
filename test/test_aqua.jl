@testitem "Aqua" tags=[:aqua] begin
    using Aqua

    Aqua.test_all(QuantumSavory,
        ambiguities=(;broken=true),
        piracies=(;broken=true),
        stale_deps=(;ignore=[:NetworkLayout]) # needed by package extension but not a condition of its loading
    )
end
