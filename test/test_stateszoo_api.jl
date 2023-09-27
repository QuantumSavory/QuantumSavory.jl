using QuantumSavory
using QuantumSavory.StatesZoo: ZALMSpinPair, SingleRailMidSwapBell, DualRailMidSwapBell
using Test

r_zalm = Register(2)
initialize!(r_zalm[1:2], ZALMSpinPair(1e-3, 0.5, 0.5, 1, 1, 1, 1, 0.9, 1e-8, 1e-8, 1e-8, 0.99))
@test ! iszero(observable(r_zalm[1:2], Z⊗Z))

r_srms = Register(2)
initialize!(r_srms[1:2], SingleRailMidSwapBell(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99))
@test ! iszero(observable(r_srms[1:2], Z⊗Z))

r_drms = Register(2)
initialize!(r_drms[1:2], DualRailMidSwapBell(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99))
@test ! iszero(observable(r_drms[1:2], Z⊗Z))