
struct QCGateSequence <: QuantumClifford.AbstractSymbolicOperator
    gates # TODO constructor that flattens nested QCGateSequence
end
function QuantumClifford.apply!(state::QuantumClifford.MixedDestabilizer, gseq::QCGateSequence, indices::AbstractVector{Int})
    for g in gseq.gates[end:-1:begin]
        apply_popindex!(state, g, indices)
    end
    state
end
apply_popindex!(state, g::QuantumClifford.AbstractSingleQubitOperator, indices::AbstractVector{Int}) = QuantumClifford.apply!(state, g(pop!(indices)))
apply_popindex!(state, g::QuantumClifford.AbstractTwoQubitOperator, indices::AbstractVector{Int}) = QuantumClifford.apply!(state, g(pop!(indices),pop!(indices)))
