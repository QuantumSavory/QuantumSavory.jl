##
# Pure States
##

abstract type SpecialKet <: Symbolic{Ket} end
istree(::SpecialKet) = false
basis(x::SpecialKet) = x.basis

@withmetadata struct XBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::XBasisState) = print(io, "|X$(num_to_sub(x.idx))⟩")

@withmetadata struct YBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::YBasisState) = print(io, "|Y$(num_to_sub(x.idx))⟩")

@withmetadata struct ZBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::ZBasisState) = print(io, "|Z$(num_to_sub(x.idx))⟩")

@withmetadata struct FockBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::FockBasisState) = print(io, "|$(num_to_sub(x.idx))⟩")

@withmetadata struct DiscreteCoherentState <: SpecialKet
    alpha::Number # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::DiscreteCoherentState) = print(io, "|$(x.alpha)⟩")

@withmetadata struct ContinuousCoherentState <: SpecialKet
    alpha::Number # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::ContinuousCoherentState) = print(io, "|$(x.alpha)⟩")

@withmetadata struct MomentumEigenState <: SpecialKet
    p::Number # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::MomentumEigenState) = print(io, "|δₚ($(x.p))⟩")

@withmetadata struct PositionEigenState <: SpecialKet
    x::Float64 # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::PositionEigenState) = print(io, "|δₓ($(x.x))⟩")

const qubit_basis = SpinBasis(1//2)
"""Basis state of σˣ"""
const X1 = const X₁ = XBasisState(1, qubit_basis)
"""Basis state of σˣ"""
const X2 = const X₂ = XBasisState(2, qubit_basis)
"""Basis state of σʸ"""
const Y1 = const Y₁ = YBasisState(1, qubit_basis)
"""Basis state of σʸ"""
const Y2 = const Y₂ = YBasisState(2, qubit_basis)
"""Basis state of σᶻ"""
const Z1 = const Z₁ = ZBasisState(1, qubit_basis)
"""Basis state of σᶻ"""
const Z2 = const Z₂ = ZBasisState(2, qubit_basis)

##
# Gates and Operators
##

abstract type AbstractSingleQubitGate <: Symbolic{Operator} end
abstract type AbstractTwoQubitGate <: Symbolic{Operator} end
istree(::AbstractSingleQubitGate) = false
istree(::AbstractTwoQubitGate) = false
basis(::AbstractSingleQubitGate) = SpinBasis(1//2)
basis(::AbstractTwoQubitGate) = SpinBasis(1//2)⊗SpinBasis(1//2)

@withmetadata struct OperatorEmbedding <: Symbolic{Operator}
    gate::Symbolic{Operator} # TODO parameterize
    indices::Vector{Int}
    basis::Basis
end
istree(::OperatorEmbedding) = true

@withmetadata struct XGate <: AbstractSingleQubitGate end
eigvecs(g::XGate) = [X1,X2]
Base.print(io::IO, ::XGate) = print(io, "X̂")
@withmetadata struct YGate <: AbstractSingleQubitGate end
eigvecs(g::YGate) = [Y1,Y2]
Base.print(io::IO, ::YGate) = print(io, "Ŷ")
@withmetadata struct ZGate <: AbstractSingleQubitGate end
eigvecs(g::ZGate) = [Z1,Z2]
Base.print(io::IO, ::ZGate) = print(io, "Ẑ")
@withmetadata struct HGate <: AbstractSingleQubitGate end
Base.print(io::IO, ::HGate) = print(io, "Ĥ")
@withmetadata struct CNOTGate <: AbstractTwoQubitGate end
Base.print(io::IO, ::CNOTGate) = print(io, "ĈNOT")
@withmetadata struct CPHASEGate <: AbstractTwoQubitGate end
Base.print(io::IO, ::CPHASEGate) = print(io, "ĈPHASE")

"""Pauli X operator, also available as the constant `σˣ`"""
const X = const σˣ = XGate()
"""Pauli Y operator, also available as the constant `σʸ`"""
const Y = const σʸ = YGate()
"""Pauli Z operator, also available as the constant `σᶻ`"""
const Z = const σᶻ = ZGate()
"""Hadamard gate"""
const H = HGate()
"""CNOT gate"""
const CNOT = CNOTGate()
"""CPHASE gate"""
const CPHASE = CPHASEGate()

##
# Other special or useful objects
##

"""Projector for a given ket

```jldoctest
julia> SProjector(X1⊗X2)
𝐏[|X₁⟩|X₂⟩]

julia> express(SProjector(X2))
Operator(dim=2x2)
  basis: Spin(1/2)
  0.5+0.0im  -0.5-0.0im
 -0.5+0.0im   0.5+0.0im
```"""
@withmetadata struct SProjector <: Symbolic{Operator}
    ket::Symbolic{Ket} # TODO parameterize
end
istree(::SProjector) = true
arguments(x::SProjector) = [x.ket]
operation(x::SProjector) = projector
QuantumOptics.projector(x::Symbolic{Ket}) = SProjector(x)
basis(x::SProjector) = basis(x.ket)
function Base.print(io::IO, x::SProjector)
    print(io,"𝐏[")
    print(io,x.ket)
    print(io,"]")
end

"""Completely depolarized state

```jldoctest
julia> MixedState(X1⊗X2)
𝕄

julia> express(MixedState(X1⊗X2))
Operator(dim=4x4)
  basis: [Spin(1/2) ⊗ Spin(1/2)]sparse([1, 2, 3, 4], [1, 2, 3, 4], ComplexF64[0.25 + 0.0im, 0.25 + 0.0im, 0.25 + 0.0im, 0.25 + 0.0im], 4, 4)

  express(MixedState(X1⊗X2), CliffordRepr())
  Rank 0 stabilizer

  ━━━━
  + X_
  + _X
  ━━━━

  ━━━━
  + Z_
  + _Z
```"""
@withmetadata struct MixedState <: Symbolic{Operator}
    basis::Basis # From QuantumOpticsBase # TODO make QuantumInterface
end
MixedState(x::Symbolic{Ket}) = MixedState(basis(x))
MixedState(x::Symbolic{Operator}) = MixedState(basis(x))
istree(::MixedState) = false
basis(x::MixedState) = x.basis
Base.print(io::IO, x::MixedState) = print(io, "𝕄")

"""The identity operator for a given basis

```judoctest
julia> IdentityOp(X1⊗X2)
𝕀

julia> express(IdentityOp(Z2))
Operator(dim=2x2)
  basis: Spin(1/2)sparse([1, 2], [1, 2], ComplexF64[1.0 + 0.0im, 1.0 + 0.0im], 2, 2)
```"""
@withmetadata struct IdentityOp <: Symbolic{Operator}
    basis::Basis # From QuantumOpticsBase # TODO make QuantumInterface
end
IdentityOp(x::Symbolic{Ket}) = IdentityOp(basis(x))
IdentityOp(x::Symbolic{Operator}) = IdentityOp(basis(x))
istree(::IdentityOp) = false
basis(x::IdentityOp) = x.basis
Base.print(io::IO, x::IdentityOp) = print(io, "𝕀")

"""State defined by a stabilizer tableau

```jldoctest
julia> StabilizerState(S"XX ZZ")
𝒮₂

julia> express(StabilizerState(S"-X"))
Ket(dim=2)
  basis: Spin(1/2)
  0.7071067811865475 + 0.0im
 -0.7071067811865475 + 0.0im
```"""
@withmetadata struct StabilizerState <: Symbolic{Ket}
    stabilizer::MixedDestabilizer
end
function StabilizerState(x::Stabilizer)
    r,c = size(x)
    @assert r==c
    StabilizerState(MixedDestabilizer(x))
end
istree(::StabilizerState) = false
basis(x::StabilizerState) = SpinBasis(1//2)^QuantumClifford.nqubits(x.stabilizer)
Base.print(io::IO, x::StabilizerState) = print(io, "𝒮$(num_to_sub(QuantumClifford.nqubits(x.stabilizer)))")
