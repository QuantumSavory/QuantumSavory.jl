using Aqua
using QuantumSavory
using QuantumClifford, QuantumOptics, Graphs

Aqua.test_all(QuantumSavory,
    ambiguities=(;broken=true),
    piracies=(;broken=true)
)
