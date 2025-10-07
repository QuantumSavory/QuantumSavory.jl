"""A background describing the T₁ decay of a two-level system."""
@kwdef struct T1Decay <: AbstractBackground
    "The T₁ time of the two-level system."
    t1::Float64 = 1e9 # TODO consider parameterizing the type
end

"""A background describing the T₂ dephasing of a two-level system."""
@kwdef struct T2Dephasing <: AbstractBackground
    "The T₂ time of the two-level system."
    t2::Float64 = 1e9 # TODO consider parameterizing the type
end

"""A depolarization background.

The `τ` parameter specifies the average time between depolarization events (assuming a Poisson point process).
I.e. after time `t` the probability for an depolarization event is `1-exp(-t/τ)`.
"""
@kwdef struct Depolarization <: AbstractBackground
    "The average time between depolarization events (assuming a Poisson point process)."
    τ::Float64 = 1e9 # TODO consider parameterizing the type
end

"""A Pauli noise background."""
@kwdef struct PauliNoise <: AbstractBackground
    "The average time between X noise events (assuming a Poisson point process)."
    τˣ::Float64 = 1e9 # TODO consider parameterizing the type
    "The average time between Y noise events (assuming a Poisson point process)."
    τʸ::Float64 = 1e9
    "The average time between Z noise events (assuming a Poisson point process)."
    τᶻ::Float64 = 1e9
end

"""A depolarization background."""
@kwdef struct AmplitudeDamping <: AbstractBackground
    "The characteristic time of the amplitude damping process."
    τ::Float64 = 1e9 # TODO consider parameterizing the type
end

"""A background combining both T₁ decay and T₂ dephasing for a two-level system."""
@kwdef struct T1T2Noise <: AbstractBackground
    "The T₁ time (energy relaxation) of the two-level system."
    t1::Float64 = 1e9
    "The T₂ time (dephasing) of the two-level system."
    t2::Float64 = 1e9

    function T1T2Noise(t1, t2)
        t2 > 2*t1 && @warn "T₂ > 2T₁ is unphysical. Setting T₂ = 2T₁" t1 t2
        new(t1, min(t2, 2*t1))
    end
end

# TODO
# T1TwirledDecay
# T1T2TwirledNoise

"""Display all available background types in QuantumSavory along with their documentation.

The `InteractiveUtils` package must be installed and imported."""
function available_background_types end
