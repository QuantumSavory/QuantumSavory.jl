"""A background describing the T₁ decay of a two-level system."""
@kwdef struct T1Decay <: AbstractBackground
    "The T₁ time of the two-level system."
    t1::Float64 = 1e9 # TODO consider parameterizing the type

    function T1Decay(t1)
        t1 = convert(Float64, t1)
        @domain t1 > 0
        return new(t1)
    end
end

"""A background describing the T₂ dephasing of a two-level system."""
@kwdef struct T2Dephasing <: AbstractBackground
    "The T₂ time of the two-level system."
    t2::Float64 = 1e9 # TODO consider parameterizing the type

    function T2Dephasing(t2)
        t2 = convert(Float64, t2)
        @domain t2 > 0
        return new(t2)
    end
end

"""A depolarization background.

The `τ` parameter specifies the average time between depolarization events (assuming a Poisson point process).
I.e. after time `t` the probability for an depolarization event is `1-exp(-t/τ)`.
"""
@kwdef struct Depolarization <: AbstractBackground
    "The average time between depolarization events (assuming a Poisson point process)."
    τ::Float64 = 1e9 # TODO consider parameterizing the type

    function Depolarization(τ)
        τ = convert(Float64, τ)
        @domain τ > 0
        return new(τ)
    end
end

"""A Pauli noise background."""
@kwdef struct PauliNoise <: AbstractBackground
    "The average time between X noise events (assuming a Poisson point process)."
    τˣ::Float64 = 1e9 # TODO consider parameterizing the type
    "The average time between Y noise events (assuming a Poisson point process)."
    τʸ::Float64 = 1e9
    "The average time between Z noise events (assuming a Poisson point process)."
    τᶻ::Float64 = 1e9

    function PauliNoise(τˣ, τʸ, τᶻ)
        τˣ = convert(Float64, τˣ)
        @domain τˣ > 0
        τʸ = convert(Float64, τʸ)
        @domain τʸ > 0
        τᶻ = convert(Float64, τᶻ)
        @domain τᶻ > 0
        return new(τˣ, τʸ, τᶻ)
    end
end

"""A depolarization background."""
@kwdef struct AmplitudeDamping <: AbstractBackground
    "The characteristic time of the amplitude damping process."
    τ::Float64 = 1e9 # TODO consider parameterizing the type

    function AmplitudeDamping(τ)
        τ = convert(Float64, τ)
        @domain τ > 0
        return new(τ)
    end
end

"""A background combining both T₁ decay and T₂ dephasing."""
@kwdef struct T1T2Noise <: AbstractBackground
    "The T₁ time of the two-level system."
    t1::Float64 = 1e9
    "The T₂ time of the two-level system."
    t2::Float64 = 1e9

    function T1T2Noise(t1, t2)
        t1 = convert(Float64, t1)
        @domain t1 > 0
        t2 = convert(Float64, t2)
        @domain t2 > 0
        return new(t1, t2)
    end
end

# TODO
# T1TwirledDecay
# T1T2TwirledNoise

public available_background_types

"""Return the available public background types along with their documentation.

Used to make a background available to tools like QuantumSavory Studio.

Concrete direct and indirect subtypes of [`AbstractBackground`](@ref) are discovered on
each call. The defining binding of each type must be public. The `InteractiveUtils`
and `REPL` standard libraries must be loaded to activate this optional method."""
function available_background_types end
