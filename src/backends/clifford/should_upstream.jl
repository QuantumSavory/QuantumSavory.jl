
struct QCGateSequence <: QuantumClifford.AbstractSymbolicOperator
    gates # TODO constructor that flattens nested QCGateSequence
end
function QuantumClifford.apply!(state::QuantumClifford.MixedDestabilizer, gseq::QCGateSequence, indices)
    for g in gseq[end:-1:begin]
        apply_popindex!(state, g, indices)
    end
    state
end
apply_popindex!(state, g::QuantumClifford.AbstractSingleQubitOperator, indices) = QuantumClifford.apply!(state, g(pop!(indices)))
apply_popindex!(state, g::QuantumClifford.AbstractTwoQubitOperator, indices) = QuantumClifford.apply!(state, g(pop!(indices),pop!(indices)))
