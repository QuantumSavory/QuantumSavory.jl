import QuantumClifford
import QuantumClifford: MixedDestabilizer

subsystemcompose(states::QuantumClifford.MixedDestabilizer...) = QuantumClifford.tensor(states...)

nsubsystems(state::QuantumClifford.MixedDestabilizer) = QuantumClifford.nqubits(state)

default_repr(::QuantumClifford.MixedDestabilizer) = CliffordRepr()

apply!(state::QuantumClifford.MixedDestabilizer, indices, operation::Type{<:QuantumClifford.AbstractSymbolicOperator}) = QuantumClifford.apply!(state, operation, indices)

ispadded(::QuantumClifford.MixedDestabilizer) = false

const _qc_l = copy(express(Z1, CliffordRepr()))
function newstate(::Qubit,::CliffordRepr)
    copy(_qc_l)
end

include("should_upstream.jl")
include("express.jl")
include("uptotime.jl")
