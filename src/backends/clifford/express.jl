
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
    @show indices
    op = embed(QuantumClifford.nqubits(state), indices, operation)
    @show QuantumClifford.expect(op, state)
end

# This is a bit of a hack to work specifically with SProjector. If you start needing more of these for other types, consider doing a bit of a redesign. This all should pass through `express(...,::UseAsObservable)`.
function observable(state::QuantumClifford.MixedDestabilizer, indices::Base.AbstractVecOrTuple{Int}, operation::SProjector)
    pstate = express(operation.ket, CliffordRepr())
    traceout_indices = setdiff(1:QuantumClifford.nqubits(state), indices)
    cstate = permutesystems(state, [indices; traceout_indices])
    cstate = QuantumClifford.traceout!(cstate, traceout_indices) # TODO just use ptrace when QuantumClifford 0.11 is out - it makes this and the next line unnecessary
    cstate = QuantumClifford.MixedDestabilizer(QuantumClifford.tab(cstate)[:,1:length(indices)], rank(cstate))
    @show cstate
    inner_product_mixed_destab(pstate, cstate)
end
