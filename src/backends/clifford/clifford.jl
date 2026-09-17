subsystemcompose(states::QuantumClifford.MixedDestabilizer...) = QuantumClifford.tensor(states...)

default_repr(::QuantumClifford.MixedDestabilizer) = CliffordRepr()

ispadded(::QuantumClifford.MixedDestabilizer) = false

_traceout_state(state::QuantumClifford.MixedDestabilizer, i) =
    QuantumClifford.ptrace(state, (i,))

const _qc_l = copy(express(Z1, CliffordRepr()))
function newstate(::Qubit,::CliffordRepr)
    copy(_qc_l)
end

include("express.jl")
include("uptotime.jl")
