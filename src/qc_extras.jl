import QuantumClifford

function uptotime!(state::QuantumClifford.MixedDestabilizer, idx::Int, background, Δt)
    prob, op = paulinoise(background, Δt)
    if rand() > prob
        QuantumClifford.apply!(state, op(idx))
    end
    state
end

function paulinoise(T2::T2Dephasing, Δt)
    exp(-Δt/T2.t2), QuantumClifford.sZ
end

subsystemcompose(states::QuantumClifford.MixedDestabilizer...) = QuantumClifford.tensor(states...)

nsubsystems(state::QuantumClifford.MixedDestabilizer) = QuantumClifford.nqubits(state)

apply!(state::QuantumClifford.MixedDestabilizer, indices, operation::Symbolic{Operator}) = QuantumClifford.apply!(state, express_qc(operation)(indices...))

express_qc(::CPHASEGate) = QuantumClifford.sCPHASE
express_qc(::CNOTGate) = QuantumClifford.sCNOT
express_qc(::XGate) = QuantumClifford.sX
express_qc(::ZGate) = QuantumClifford.sZ

function project_traceout!(state::QuantumClifford.MixedDestabilizer,stateindex,basis::Symbolic{Operator})
    # do this if ispadded() = true
    #state, res = express_qc_proj(basis)(state, stateindex)
    # do this if ispadded() = false
    state, res = QuantumClifford.projectremoverand!(state, express_qc_proj(basis), stateindex)
    res÷2+1, state
end

express_qc_proj(::XGate) = QuantumClifford.projectX! # should be project*rand! if ispadded()=true
express_qc_proj(::YGate) = QuantumClifford.projectY! # should be project*rand! if ispadded()=true
express_qc_proj(::ZGate) = QuantumClifford.projectZ! # should be project*rand! if ispadded()=true

function observable(state::QuantumClifford.MixedDestabilizer, indices, operation)
    op = QuantumClifford._expand_pauli(operation,indices,QuantumClifford.nqubits(state)) # TODO create a public `embed` function in QuantumClifford
    QuantumClifford.expect(op, state)
end

ispadded(::QuantumClifford.MixedDestabilizer) = false

traceout!(s::QuantumClifford.MixedDestabilizer,i) = QuantumClifford.traceoutremove!(s,i) # QuantumClifford.traceout!(s,i) if ispadded()=true
