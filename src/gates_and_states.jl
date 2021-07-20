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

abstract type AbstractState end
struct XState <: AbstractState
    subspace::Int
end
struct YState <: AbstractState
    subspace::Int
end
struct ZState <: AbstractState
    subspace::Int
end

const X₀ = XState(0)
const X₁ = XState(1)
const Y₀ = YState(0)
const Y₁ = YState(1)
const Z₀ = ZState(0)
const Z₁ = ZState(1)

end