@testitem "StatesZoo API" tags=[:stateszoo_api] begin
using QuantumSavory.StatesZoo: ZALMSpinPairW, ZALMSpinPair, SingleRailMidSwapBellW, SingleRailMidSwapBell, DualRailMidSwapBellW, DualRailMidSwapBell
using QuantumOpticsBase

zalmW = ZALMSpinPairW(1e-3, 0.5, 0.5, 1, 1, 1, 1, 0.9, 1e-8, 1e-8, 1e-8, 0.99)
zalm = ZALMSpinPair(1e-3, 0.5, 0.5, 1, 1, 1, 1, 0.9, 1e-8, 1e-8, 1e-8, 0.99)
srmsW = SingleRailMidSwapBellW(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)
srms = SingleRailMidSwapBell(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)
drmsW = DualRailMidSwapBellW(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)
drms = DualRailMidSwapBell(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99)

r_zalmW = Register(2)
initialize!(r_zalmW[1:2], zalmW)
@test ! iszero(observable(r_zalmW[1:2], Z⊗Z))

r_zalm = Register(2)
initialize!(r_zalm[1:2], zalm)
@test ! iszero(observable(r_zalm[1:2], Z⊗Z))

r_srmsW = Register(2)
initialize!(r_srmsW[1:2], srmsW)
@test ! iszero(observable(r_srmsW[1:2], Z⊗Z))

r_srms = Register(2)
initialize!(r_srms[1:2], srms)
@test ! iszero(observable(r_srms[1:2], Z⊗Z))

r_drmsW = Register(2)
initialize!(r_drmsW[1:2], drmsW)
@test ! iszero(observable(r_drmsW[1:2], Z⊗Z))

r_drms = Register(2)
initialize!(r_drms[1:2], drms)
@test ! iszero(observable(r_drms[1:2], Z⊗Z))

@test tr(zalm) ≈ tr(express(zalm))

@test tr(srms) ≈ tr(express(srms))

@test tr(drms) ≈ tr(express(drms))
end
