abstract type AbstractMeasurement end

"""
    HomodyneMeasurement(angles; squeeze = eps())

Describe a homodyne measurement on one or more continuous-variable modes.

`angles` gives the quadrature angle, in radians, for each measured mode.
For example, `0.0` corresponds to an `x`-quadrature measurement and `pi/2`
to a `p`-quadrature measurement. `squeeze` sets the finite-squeezing parameter
used by Gaussian backends when approximating the ideal measurement.

This is typically used together with [`project_traceout!`](@ref) on a
continuous-variable register slot.

```jldoctest; setup = :(using QuantumSavory, Gabs)
julia> reg = Register([Qumode()], [GabsRepr(QuadBlockBasis)]);

julia> initialize!(reg[1], CoherentState(0.3 + 0.2im));

julia> result = project_traceout!(reg[1], HomodyneMeasurement([0.0]; squeeze = 1e-12));

julia> println(replace(sprint(show, MIME"text/plain"(), result), r"-?[0-9]+[.][0-9]+(?:e[+-]?[0-9]+)?" => "0.0"))
2-element Vector{Float64}:
 0.0
 0.0

julia> isnothing(QuantumSavory.stateof(reg[1]))
true
```
"""
struct HomodyneMeasurement <: AbstractMeasurement
    angles::Vector{Real}
    squeeze::Real
end
HomodyneMeasurement(angles::Vector{<:Real}; squeeze = eps()) = HomodyneMeasurement(angles, squeeze)
