using QuantumSavory
using QuantumSymbolics

const Transduction = exp(im * (π/2) * (σ₊ ⊗ â + σ₋ ⊗ âꜛ))

squeezing = 0.5
nodeA = Register([Qubit(), Qumode()])
nodeB = Register([Qubit(), Qumode()])

initialize!(nodeA[1], Z2)
initialize!(nodeB[1], Z2)
initialize!((nodeA[2], nodeB[2]), TwoSqueezedState(squeezing))

apply!(nodeA[1:2], Transduction)
apply!(nodeB[1:2], Transduction)

project_traceout!(nodeA[2], HomodyneMeasurement([0.0]))
project_traceout!(nodeB[2], HomodyneMeasurement([0.0]))

real(observable((nodeA[1], nodeB[1]), projector(StabilizerState("XX ZZ"))))
