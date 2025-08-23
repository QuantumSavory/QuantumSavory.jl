subsystemcompose(states::QuantumClifford.MixedDestabilizer...) = QuantumClifford.tensor(states...)

default_repr(::QuantumClifford.MixedDestabilizer) = CliffordRepr()

ispadded(::QuantumClifford.MixedDestabilizer) = false

const _qc_l = copy(express(Z1, CliffordRepr()))
function newstate(::Qubit,::CliffordRepr)
    copy(_qc_l)
end

include("gate_sequence_to_upstream.jl")  # TODO: upstream QCGateSequence to QuantumClifford
include("express.jl")
include("uptotime.jl")
