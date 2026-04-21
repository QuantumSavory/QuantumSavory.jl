
function project_traceout!(state::QuantumClifford.MixedDestabilizer,stateindex::Int,basis::Symbolic{AbstractOperator})
    # do this if ispadded() = true
    #state, res = express_qc_proj(basis)(state, stateindex)
    # do this if ispadded() = false
    proj = QuantumClifford.projectremoverand!(state, express_qc_proj(basis), stateindex)
    state = proj[1]
    res = proj[2]::UInt8 # type assert to help with inference # TODO fix this upstream in QuantumClifford
    res÷2+1, state
end

express_qc_proj(::XGate) = QuantumClifford.projectX! # should be project*rand! if ispadded()=true
express_qc_proj(::YGate) = QuantumClifford.projectY! # should be project*rand! if ispadded()=true
express_qc_proj(::ZGate) = QuantumClifford.projectZ! # should be project*rand! if ispadded()=true

function observable(state::QuantumClifford.MixedDestabilizer, indices::Base.AbstractVecOrTuple{Int}, operation)
    operation = express(operation, CliffordRepr(), UseAsObservable())::QuantumClifford.PauliOperator
    op = embed(QuantumClifford.nqubits(state), indices, operation)
    QuantumClifford.expect(op, state)
end

# This is a bit of a hack to work specifically with SProjector. If you start needing more of these for other types, consider doing a bit of a redesign. This all should pass through `express(...,::UseAsObservable)`.
function observable(state::QuantumClifford.MixedDestabilizer, indices::Base.AbstractVecOrTuple{Int}, operation::SProjector)
    pstate = express(operation.ket, CliffordRepr())
    QuantumClifford.nqubits(state)==length(indices)==QuantumClifford.nqubits(pstate) || error("An attempt was made to measure a projection observable while using Clifford representation for the qubits. However, the qubits that are being observed are entangled with other qubits. Currently this is not supported. Consider tracing out the extra qubits or using Pauli observables that do not suffer from this embedding limitation. Message us on the issue tracker if you want this functionality implemented.")
    cstate = permutesystems(state, indices)
    dot(pstate, cstate)
end
