"""A background describing the T₁ decay of a two-level system."""
struct T1Decay <: AbstractBackground
    "The T₁ time of the two-level system."
    t1::Float64 # TODO consider parameterizing the type
end

"""A background describing the T₂ dephasing of a two-level system."""
struct T2Dephasing <: AbstractBackground
    "The T₂ time of the two-level system."
    t2::Float64 # TODO consider parameterizing the type
end

"""A depolarization background.

The `τ` parameter specifies the average time between depolarization events (assuming a Poisson point process).
I.e. after time `t` the probability for an depolarization event is `1-exp(-t/τ)`.
"""
struct Depolarization <: AbstractBackground
    "The average time between depolarization events (assuming a Poisson point process)."
    τ::Float64 # TODO consider parameterizing the type
end

"""A Pauli noise background."""
struct PauliNoise <: AbstractBackground
    "The average time between X noise events (assuming a Poisson point process)."
    τˣ::Float64 # TODO consider parameterizing the type
    "The average time between Y noise events (assuming a Poisson point process)."
    τʸ::Float64
    "The average time between Z noise events (assuming a Poisson point process)."
    τᶻ::Float64
end

"""A depolarization background."""
struct AmplitudeDamping <: AbstractBackground
    "The characteristic time of the amplitude damping process."
    τ::Float64 # TODO consider parameterizing the type
end

# TODO
# T1T2Noise
# T1TwirledDecay
# T1T2TwirledNoise

"""Display all available background types in QuantumSavory along with their documentation.

The `InteractiveUtils` package must be installed and imported."""
function available_background_types end
