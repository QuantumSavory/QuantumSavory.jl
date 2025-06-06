import QuantumSavory
include("./apply.jl")
include("./traceout.jl")
include("../baseops/RGate.jl")


struct EntanglementSwap <: QuantumSavory.CircuitZoo.AbstractCircuit
    ϵ_g::Float64
    ξ::Float64
    rng::AbstractRNG

    function EntanglementSwap(ϵ_g::Float64, ξ::Float64, rng::AbstractRNG=Random.GLOBAL_RNG)
        @assert 0 <= ϵ_g <= 1   "ϵ_g must be in [0, 1]"
        @assert 0 <=  ξ  <= 1   "ξ must be in [0, 1]"

        new(ϵ_g, ξ, rng)
    end
end
function (circuit::EntanglementSwap)(localL, remoteL, localR, remoteR)
    apply!((localL, localR), QuantumSavory.CNOT; ϵ_g=circuit.ϵ_g)
    xmeas = project_traceout!(localL, QuantumSavory.σˣ; ξ=circuit.ξ, rng=circuit.rng)
    zmeas = project_traceout!(localR, QuantumSavory.σᶻ; ξ=circuit.ξ, rng=circuit.rng)
    if xmeas==2
        QuantumSavory.apply!(remoteL, QuantumSavory.Z)
    end
    if zmeas==2
        QuantumSavory.apply!(remoteR, QuantumSavory.X)
    end
    return xmeas, zmeas
end
inputqubits(::EntanglementSwap) = 4


struct DEJMPSProtocol <: QuantumSavory.CircuitZoo.AbstractCircuit
    ϵ_g::Float64
    ξ::Float64

    function DEJMPSProtocol(ϵ_g::Float64, ξ::Float64)
        @assert 0 <= ϵ_g <= 1   "ϵ_g must be in [0, 1]"
        @assert 0 <=  ξ  <= 1   "ξ must be in [0, 1]"

        new(ϵ_g, ξ)
    end
end
function (circuit::DEJMPSProtocol)(purifiedL, purifiedR, sacrificedL, sacrificedR)
    QuantumSavory.apply!(purifiedL, Rx(π/2))
    QuantumSavory.apply!(sacrificedL, Rx(π/2))
    QuantumSavory.apply!(purifiedR, Rx(-π/2))
    QuantumSavory.apply!(sacrificedR, Rx(-π/2))

    apply!([purifiedL, sacrificedL], QuantumSavory.CNOT; ϵ_g=circuit.ϵ_g)
    apply!([purifiedR, sacrificedR], QuantumSavory.CNOT; ϵ_g=circuit.ϵ_g)

    measa = project_traceout!(sacrificedL, QuantumSavory.σᶻ; ξ=circuit.ξ)
    measb = project_traceout!(sacrificedR, QuantumSavory.σᶻ; ξ=circuit.ξ)

    success = measa == measb
    if !success
        QuantumSavory.traceout!(purifiedL)
        QuantumSavory.traceout!(purifiedR)
    end
    return success
end
inputqubits(::DEJMPSProtocol) = 4