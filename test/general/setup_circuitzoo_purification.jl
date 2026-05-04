using QuantumSavory.CircuitZoo
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1, Purify3to1, Purify3to1Node, Purify2to1Node, PurifyStringent, StringentHead, StringentBody, PurifyExpedient, PurifyStringentNode, PurifyExpedient
using QuantumSavory.StatesZoo

const bell = StabilizerState("XX ZZ")
export bell;
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).

noisy_pair_func(F) = DepolarizedBellPair(;F)
