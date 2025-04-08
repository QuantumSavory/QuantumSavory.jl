subsystemcompose(states::QuantumClifford.MixedDestabilizer...) = QuantumClifford.tensor(states...)

default_repr(::QuantumClifford.MixedDestabilizer) = CliffordRepr()

ispadded(::QuantumClifford.MixedDestabilizer) = false

const _qc_l = copy(express(Z1, CliffordRepr()))
function newstate(::Qubit,::CliffordRepr)
    copy(_qc_l)
end

include("should_upstream.jl")
include("express.jl")
include("uptotime.jl")
