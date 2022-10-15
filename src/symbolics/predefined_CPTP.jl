export PauliNoiseCPTP, DephasingCPTP, DephasingCPTP, GateCPTP

abstract type NoiseCPTP <: Symbolic{SuperOperator} end
istree(::NoiseCPTP) = false
basis(x::NoiseCPTP) = x.basis

"""Single-qubit Pauli noise CPTP map

```jldoctest
julia> apply!(express(Z1), [1], PauliNoiseCPTP(1/4,1/4,1/4))
Operator(dim=2x2)
  basis: Spin(1/2)
 0.5+0.0im  0.0+0.0im
 0.0+0.0im  0.5+0.0im
```"""
@withmetadata struct PauliNoiseCPTP <: NoiseCPTP
    px
    py
    pz
end
basis(x::PauliNoiseCPTP) = SpinBasis(1//2)
Base.print(io::IO, x::PauliNoiseCPTP) = print(io, "𝒫")

"""Single-qubit dephasing CPTP map"""
@withmetadata struct DephasingCPTP <: NoiseCPTP
    p
end
basis(x::DephasingCPTP) = SpinBasis(1//2)
Base.print(io::IO, x::DephasingCPTP) = print(io, "𝒟𝓅𝒽")

"""Single-qubit depolarization CPTP map"""
@withmetadata struct DepolarizationCPTP <: NoiseCPTP
    p
    basis::Basis
end
Base.print(io::IO, x::DepolarizationCPTP) = print(io, "𝒟ℯ𝓅ℴ𝓁")

"""A unitary gate followed by a CPTP map"""
@withmetadata struct GateCPTP <: NoiseCPTP
    gate::Symbolic{Operator}
    cptp::NoiseCPTP
end
basis(x::GateCPTP) = basis(x.cptp)
function Base.print(io::IO, x::GateCPTP)
    print(io, x.cptp)
    print(io, "[")
    print(io, x.gate)
    print(io, "]")
end
