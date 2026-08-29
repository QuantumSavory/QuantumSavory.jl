abstract type AbstractMeasurement end

"""
    HomodyneMeasurement(angles)

Describe a homodyne measurement on a continuous-variable mode.

`angles` gives the quadrature angle, in radians, for each measured mode.
For example, `0.0` corresponds to an `x`-quadrature measurement and `pi/2`
to a `p`-quadrature measurement.

Register-level [`project_traceout!`](@ref) accepts one qmode slot and one angle.
It returns the complex phase-space label `z = x + im*p` of the sampled
projector. For angle `θ`, recover the measured quadrature with
`real(exp(-im*θ) * z)`. The label is not generally an annihilation-operator
eigenvalue.

```jldoctest; setup = :(using QuantumSavory, Gabs)
julia> reg = Register([Qumode()], [GabsRepr(QuadBlockBasis)]);

julia> initialize!(reg[1], CoherentState(0.3 + 0.2im));

julia> result = project_traceout!(reg[1], HomodyneMeasurement([0.0]));

julia> result isa Complex
true

julia> isfinite(real(result)) && isfinite(imag(result))
true

julia> isnothing(QuantumSavory.stateof(reg[1]))
true
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
