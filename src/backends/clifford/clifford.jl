import QuantumClifford

subsystemcompose(states::QuantumClifford.MixedDestabilizer...) = QuantumClifford.tensor(states...)

nsubsystems(state::QuantumClifford.MixedDestabilizer) = QuantumClifford.nqubits(state)

default_repr(::QuantumClifford.MixedDestabilizer) = CliffordRepr()

apply!(state::QuantumClifford.MixedDestabilizer, indices, operation::Type{<:QuantumClifford.AbstractSymbolicOperator}) = QuantumClifford.apply!(state, operation, indices)

ispadded(::QuantumClifford.MixedDestabilizer) = false

traceout!(s::QuantumClifford.MixedDestabilizer,i) = QuantumClifford.traceoutremove!(s,i) # QuantumClifford.traceout!(s,i) if ispadded()=true

function newstate(::Qubit,::CliffordRepr)
    copy(_qc_l)
end

include("should_upstream.jl")
include("express.jl")
include("uptotime.jl")
