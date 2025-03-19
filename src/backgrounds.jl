"""A background describing the T₁ decay of a two-level system."""
struct T1Decay <: AbstractBackground
    t1
end

"""A background describing the T₂ dephasing of a two-level system."""
struct T2Dephasing <: AbstractBackground
    t2
end

"""A depolarization background.

The `τ` parameter specifies the average time between depolarization events (assuming a Poisson point process).
I.e. after time `t` the probability for an depolarization event is `1-exp(-t/τ)`.
"""
struct Depolarization <: AbstractBackground
    τ
end

"""A Pauli noise background."""
struct PauliNoise <: AbstractBackground
    τˣ
    τʸ
    τᶻ
end

"""A depolarization background."""
struct AmplitudeDamping <: AbstractBackground
    τ
end

# TODO
# T1T2Noise
# T1TwirledDecay
# T1T2TwirledNoise
