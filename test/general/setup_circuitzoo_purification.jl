using QuantumSavory.CircuitZoo
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1, Purify3to1, Purify3to1Node, Purify2to1Node, PurifyStringent, StringentHead, StringentBody, PurifyExpedient, PurifyStringentNode, PurifyExpedient

const bell = StabilizerState("XX ZZ")
export bell;
# or equivalently `const bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2`,
# however converting to stabilizer state for Clifford simulations
# is not implemented (and can not be done efficiently).


# QOptics repr
const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm # TODO make a depolarization helper


# Qclifford repr
const stab_perfect_pair = StabilizerState("XX ZZ")
const stab_perfect_pair_dm = SProjector(stab_perfect_pair)
const stab_mixed_dm = MixedState(stab_perfect_pair_dm)
stab_noisy_pair_func(F) = F*stab_perfect_pair_dm + (1-F)*stab_mixed_dm
