# Include the already implemented code for first gen repeaters
include("firstgenrepeater_setup.jl")

# Overwrite some of the initialization and expectation value definitions
import QuantumClifford

# Using QuantumClifford.jl to create a noisy Bell pair object,
# in tableau representation.
const qc_perfect_pair = QuantumClifford.MixedDestabilizer(QuantumClifford.bell())
const qc_mixed = QuantumClifford.traceout!(copy(qc_perfect_pair), [1,2])
function qc_noisy_pair(F)
    if rand() < F
        return qc_perfect_pair
    else
        return qc_mixed
    end
end
const qc_XX = QuantumClifford.P"XX"
const qc_ZZ = QuantumClifford.P"ZZ"
const qc_YY = QuantumClifford.P"YY"
