using Test
using QuantumSavory

state = 1im*X2⊗Z1+2*Y1⊗(Z2+X2)+StabilizerState(S"XZ YY")
express(state)
express(state)
state = 1im*X1⊗Z2+2*Y2⊗(Z1+X1)+StabilizerState(S"YX ZZ")
nocache = @timed express(state)
withcache = @timed express(state)
@test nocache.time > 10*withcache.time
@test withcache.bytes == 0
@test nocache.value ≈ withcache.value ≈ express(1im*X1⊗Z2+2*Y2⊗(Z1+X1)+StabilizerState(S"YX ZZ"))

state = 1im*X1⊗Z2+2*Y2⊗(Z1+X1)+StabilizerState(S"YX ZZ")
state = SProjector(state)+2*X⊗(Z+Y)/3im
state = state+MixedState(state)
state2 = deepcopy(state)
express(state)
express(state)
nocache = @timed express(state2)
withcache = @timed express(state2)
@test nocache.time > 50*withcache.time
@test withcache.bytes == 0
@test nocache.value ≈ withcache.value ≈ express(state2)

state = StabilizerState(S"ZZ XX")
state = SProjector(state)*0.5 + 0.5*MixedState(state)
state2 = deepcopy(state)
express(state, CliffordRepr())
express(state, CliffordRepr())
express(state2)
express(state2)
nocache = @timed express(state2, CliffordRepr())
withcache = @timed express(state2, CliffordRepr())
@test nocache.time > 2*withcache.time
@test withcache.bytes <= 200
results = Set([express(state2, CliffordRepr()) for i in 1:20])
@test length(results)==2
