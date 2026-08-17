using QuantumSavory
using QuantumSymbolics

const Transduction = exp(im * (π/2) * (σ₊ ⊗ â + σ₋ ⊗ âꜛ))

nodeA = Register([Qubit(), Qumode()])
nodeB = Register([Qubit(), Qumode()])

initialize!(nodeA[1], Z2)
initialize!(nodeB[1], Z2)
initialize!((nodeA[2], nodeB[2]), (F0 ⊗ F0 + F1 ⊗ F1) / sqrt(2))

apply!(nodeA[1:2], Transduction)
apply!(nodeB[1:2], Transduction)

real(observable((nodeA[1], nodeB[1]), projector(StabilizerState("-XX ZZ"))))
