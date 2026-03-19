abstract type AbstractMeasurement end

"""
    HomodyneMeasurement(angles; squeeze = eps())

Describe a homodyne measurement on one or more continuous-variable modes.

`angles` gives the quadrature angle, in radians, for each measured mode.
For example, `0.0` corresponds to an `x`-quadrature measurement and `pi/2`
to a `p`-quadrature measurement. `squeeze` sets the finite-squeezing parameter
used by Gaussian backends when approximating the ideal measurement.

```jldoctest
julia> meas = HomodyneMeasurement([0.0]; squeeze = 1e-12);

julia> meas.angles
1-element Vector{Real}:
 0.0

julia> meas.squeeze
1.0e-12
```
"""
struct HomodyneMeasurement <: AbstractMeasurement
    angles::Vector{Real}
    squeeze::Real
end
HomodyneMeasurement(angles::Vector{<:Real}; squeeze = eps()) = HomodyneMeasurement(angles, squeeze)
