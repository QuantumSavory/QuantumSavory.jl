module Gates

# Reuse Yao

abstract type AbstractGate end
abstract type AbstractUGate <: AbstractGate end
abstract type AbstractSingleQubitGate <: AbstractUGate end
abstract type AbstractTwoQubitGate <: AbstractUGate end

struct XGate <: AbstractSingleQubitGate end
struct YGate <: AbstractSingleQubitGate end
struct ZGate <: AbstractSingleQubitGate end
struct HGate <: AbstractSingleQubitGate end
struct CNOTGate <: AbstractTwoQubitGate end
struct CPHASEGate <: AbstractTwoQubitGate end

const X = XGate()
const Y = YGate()
const Z = ZGate()
const H = HGate()
const CNOT = CNOTGate()
const CPHASE = CPHASEGate()

struct Depolarize <: AbstractGate
    p::Float64
end

abstract type AbstractMeasurement end
abstract type AbstractProjector <: AbstractMeasurement end
struct XProjector <: AbstractProjector
    subspace::Int
end
struct YProjector <: AbstractProjector
    subspace::Int
end
struct ZProjector <: AbstractProjector
    subspace::Int
end

const Pˣ₀ = XProjector(0)
const Pˣ₁ = XProjector(1)
const Pʸ₀ = YProjector(0)
const Pʸ₁ = YProjector(1)
const Pᶻ₀ = ZProjector(0)
const Pᶻ₁ = ZProjector(1)

end

module States

abstract type AbstractBasis end
struct XBasis <: AbstractBasis
    subspace::Int
end
struct YBasis <: AbstractBasis
    subspace::Int
end
struct ZBasis <: AbstractBasis
    subspace::Int
end

const X₀ = XBasis(0) # TODO why are you indexing from zero?
const X₁ = XBasis(1)
const Y₀ = YBasis(0)
const Y₁ = YBasis(1)
const Z₀ = ZBasis(0)
const Z₁ = ZBasis(1)

end

function basisvectors(basis::Type{<:States.AbstractBasis})
    [basis(i) for i in indexspan(basis)]
end

indexspan(::Type{States.XBasis}) = (0,1)
indexspan(::Type{States.YBasis}) = (0,1)
indexspan(::Type{States.ZBasis}) = (0,1)
