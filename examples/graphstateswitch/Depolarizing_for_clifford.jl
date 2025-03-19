using QuantumSavory

state = StabilizerState("XX ZZ")

p = 0.1
depolarized_state = p*SProjector(state) + (1-p)*MixedState(state)
@info express(MixedState(state), CliffordRepr())

@info express(MixedState(X1), CliffordRepr())