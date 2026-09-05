abstract type AbstractMeasurement end

@doc raw"""
    HomodyneMeasurement(angles)

Describe a homodyne measurement on a continuous-variable mode.

`angles` gives the quadrature angle, in radians, for each measured mode.
For example, `0.0` corresponds to an `x`-quadrature measurement and `pi/2`
to a `p`-quadrature measurement. In the default ``\hbar=2`` units, the
measured observable is

```math
\hat q_\theta = e^{-i\theta}\hat a + e^{i\theta}\hat a^\dagger.
```

For an outcome ``q_\theta``, the ideal measurement applies a projector on the
following state:

```math
|q_\theta;\theta\rangle, \qquad
\hat q_\theta |q_\theta;\theta\rangle =
q_\theta |q_\theta;\theta\rangle.
```

This quadrature eigenstate is an ideal infinitely squeezed state: its measured
quadrature has zero variance and its conjugate quadrature has unbounded
variance. [`project_traceout!`](@ref) returns the real outcome ``q_\theta`` and
removes the measured mode.

Register-level [`project_traceout!`](@ref) accepts one qmode slot and one angle.

```jldoctest; setup = :(using QuantumSavory, Gabs)
julia> reg = Register([Qumode()], [GabsRepr(QuadBlockBasis)]);

julia> initialize!(reg[1], CoherentState(0.3 + 0.2im));

julia> result = project_traceout!(reg[1], HomodyneMeasurement([0.0]));
```
"""
struct HomodyneMeasurement <: AbstractMeasurement
    angles::Vector{Real}
    cache::Dict{Any,Any}
end
HomodyneMeasurement(angles::Vector{<:Real}) =
    HomodyneMeasurement(angles, Dict{Any,Any}())
Base.show(io::IO, measurement::HomodyneMeasurement) = print(
    io, "HomodyneMeasurement(", measurement.angles, ")"
)
