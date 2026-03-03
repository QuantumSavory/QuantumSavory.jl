
struct QCGateSequence <: QuantumClifford.AbstractSymbolicOperator
    gates # TODO constructor that flattens nested QCGateSequence
end
function QuantumClifford.apply!(state::QuantumClifford.MixedDestabilizer, indices::AbstractVector{Int}, gseq::QCGateSequence)
    for g in gseq.gates[end:-1:begin]
        apply_popindex!(state, indices, g)
    end
    state
end
apply_popindex!(state, indices::AbstractVector{Int}, g::Type{<:QuantumClifford.AbstractSingleQubitOperator}) =
    QuantumClifford.apply!(state, g(pop!(indices)::Int))
apply_popindex!(state, indices::AbstractVector{Int}, g::Type{<:QuantumClifford.AbstractTwoQubitOperator}) =
    QuantumClifford.apply!(state, g(pop!(indices)::Int, pop!(indices)::Int))

projector(state::QuantumClifford.Stabilizer) = projector(StabilizerState(state)) # convert to a type that QuantumSymbolics can handle
