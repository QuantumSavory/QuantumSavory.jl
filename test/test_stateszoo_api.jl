using QuantumSavory
using QuantumSavory.StatesZoo: ZALMSpinPairU, ZALMSpinPairN, SingleRailMidSwapBellU, SingleRailMidSwapBellN, DualRailMidSwapBellU, DualRailMidSwapBellN
using LinearAlgebra
using Test

zalmU = ZALMSpinPairU(1e-3, 0.5, 0.5, 1, 1, 1, 1, 0.9, 1e-8, 1e-8, 1e-8, 0.99)
zalmN = ZALMSpinPairN(1e-3, 0.5, 0.5, 1, 1, 1, 1, 0.9, 1e-8, 1e-8, 1e-8, 0.99)
srmsU = SingleRailMidSwapBellU(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)
srmsN = SingleRailMidSwapBellN(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)
drmsU = DualRailMidSwapBellU(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)
drmsN = DualRailMidSwapBellN(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)

r_zalmU = Register(2)
initialize!(r_zalmU[1:2], zalmU)
@test ! iszero(observable(r_zalmU[1:2], Z⊗Z))

r_zalmN = Register(2)
initialize!(r_zalmN[1:2], zalmN)
@test ! iszero(observable(r_zalmN[1:2], Z⊗Z))

r_srmsU = Register(2)
initialize!(r_srmsU[1:2], srmsU)
@test ! iszero(observable(r_srmsU[1:2], Z⊗Z))

r_srmsN = Register(2)
initialize!(r_srmsN[1:2], srmsN)
@test ! iszero(observable(r_srmsN[1:2], Z⊗Z))

r_drmsU = Register(2)
initialize!(r_drmsU[1:2], drmsU)
@test ! iszero(observable(r_drmsU[1:2], Z⊗Z))

r_drmsN = Register(2)
initialize!(r_drmsN[1:2], drmsN)
@test ! iszero(observable(r_drmsN[1:2], Z⊗Z))

@test tr(zalmU) < 1.0
@test tr(express(zalmN).data) ≈ 1

@test tr(srmsU) < 1.0
@test tr(express(srmsN).data) ≈ 1.0

@test tr(drmsU) < 1.0
@test tr(express(drmsN).data) ≈ 1.0