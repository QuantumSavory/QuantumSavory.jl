function project_traceout!(state::QuantumClifford.MixedDestabilizer,stateindex,basis::Symbolic{AbstractOperator})
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

function observable(state::QuantumClifford.MixedDestabilizer, indices, operation)
    operation = express_nolookup(operation, CliffordRepr(), UseAsObservable())
    op = QuantumClifford._expand_pauli(operation,indices,QuantumClifford.nqubits(state)) # TODO create a public `embed` function in QuantumClifford
    QuantumClifford.expect(op, state)
end
