import QuantumClifford

subsystemcompose(states::QuantumClifford.MixedDestabilizer...) = QuantumClifford.tensor(states...)

nsubsystems(state::QuantumClifford.MixedDestabilizer) = QuantumClifford.nqubits(state)

apply!(state::QuantumClifford.MixedDestabilizer, indices, operation::Symbolic{Operator}) = QuantumClifford.apply!(state, express_qc_op(operation), indices)

ispadded(::QuantumClifford.MixedDestabilizer) = false

traceout!(s::QuantumClifford.MixedDestabilizer,i) = QuantumClifford.traceoutremove!(s,i) # QuantumClifford.traceout!(s,i) if ispadded()=true

function newstate(::Qubit,::QuantumCliffordRepresentation)
    copy(_qc_l)
end

include("should_upstream.jl")
include("express.jl")
include("uptotime.jl")
