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

apply!(state::QuantumClifford.MixedDestabilizer, indices, operation::Symbolic{Operator}) = QuantumClifford.apply!(state, express_qc_op(operation), indices)
QuantumClifford.apply!(state::QuantumClifford.MixedDestabilizer, op::Type{<:QuantumClifford.AbstractSymbolicOperator}, indices) = QuantumClifford.apply!(state, op(indices...)) # TODO piracy to be moved to QuantumClifford

const _qc_l = MixedDestabilizer(S"Z")
const _qc_h = MixedDestabilizer(S"-Z")
const _qc_s₊ = MixedDestabilizer(S"X")
const _qc_s₋ = MixedDestabilizer(S"-X")
const _qc_i₊ = MixedDestabilizer(S"Y")
const _qc_i₋ = MixedDestabilizer(S"-Y")

express_nolookup(s::XBasisState, ::QuantumCliffordRepresentation) = (_qc_s₊,_qc_s₋)[s.idx]
express_nolookup(s::YBasisState, ::QuantumCliffordRepresentation) = (_qc_i₊,_qc_i₋)[s.idx]
express_nolookup(s::ZBasisState, ::QuantumCliffordRepresentation) = (_qc_l,_qc_h)[s.idx]

# TODO fold express_qc_op into the normal express framework
express_qc_op(::CPHASEGate) = QuantumClifford.sCPHASE
express_qc_op(::CNOTGate) = QuantumClifford.sCNOT
express_qc_op(::XGate) = QuantumClifford.sX
express_qc_op(::ZGate) = QuantumClifford.sZ
express_qc_op(x::STensorOperator) = QCGateSequence([express_qc_op(t) for t in x.terms])
struct QCGateSequence # TODO maybe move to QuantumClifford
    gates # TODO union of gates and QCGateSequence
end
function QuantumClifford.apply!(state::QuantumClifford.MixedDestabilizer, gseq::QCGateSequence, indices)
    for g in gseq
        apply_popindex!(state, g, indices)
    end
    state
end
apply_popindex!(state, g::QuantumClifford.AbstractSingleQubitOperator, indices) = QuantumClifford.apply!(state, g(pop!(indices)))
apply_popindex!(state, g::QuantumClifford.AbstractTwoQubitOperator, indices) = QuantumClifford.apply!(state, g(pop!(indices),pop!(indices)))

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
    operation = validate_qc_observable(operation)
    op = QuantumClifford._expand_pauli(operation,indices,QuantumClifford.nqubits(state)) # TODO create a public `embed` function in QuantumClifford
    QuantumClifford.expect(op, state)
end
# TODO fold validate_qc_observable into the normal express framework
validate_qc_observable(op::QuantumClifford.PauliOperator) = op
validate_qc_observable(op::STensorOperator) = QuantumClifford.tensor(validate_qc_observable.(arguments(op))...)
validate_qc_observable(::XGate) = QuantumClifford.P"X"
validate_qc_observable(::YGate) = QuantumClifford.P"Y"
validate_qc_observable(::ZGate) = QuantumClifford.P"Z"
validate_qc_observable(op::SScaledOperator) = arguments(op)[1] * validate_qc_observable(arguments(op)[2])
validate_qc_observable(op) = error("can not convert $(op) into a PauliOperator, which is the only observable that can be computed for QuantumClifford objects")

ispadded(::QuantumClifford.MixedDestabilizer) = false

traceout!(s::QuantumClifford.MixedDestabilizer,i) = QuantumClifford.traceoutremove!(s,i) # QuantumClifford.traceout!(s,i) if ispadded()=true

function newstate(::Qubit,::QuantumCliffordRepresentation)
    copy(_qc_l)
end

struct QCRandomSampler # TODO specify types
    operators # union of QCRandomSampler and MixedDestabilizer
    weights
end
function express_nolookup(x::SAddOperator, repr::QuantumCliffordRepresentation)
    weights = collect(values(x.dict))
    symops = collect(keys(x.dict))
    # TODO assert norms of operators are all ==1
    @assert sum(weights) ≈ 1.0
    ops = express_nolookup.(symops, (repr,))
    QCRandomSampler(ops, weights)
end
function express_from_cache(x::QCRandomSampler)
    threshold = rand()
    cweights = cumsum(x.weights)
    i = findfirst(>=(threshold), cweights) # TODO make alloc free
    express_from_cache(x.operators[i])
end
function express_nolookup(x::MixedState, ::QuantumCliffordRepresentation)
    nqubits = length(x.basis.bases)
    # TODO assert all are qubits
    one(MixedDestabilizer,0,nqubits)
end
express_nolookup(x::SProjector, repr::QuantumCliffordRepresentation) = express_nolookup(x.ket, repr)
express_nolookup(x::StabilizerState, ::QuantumCliffordRepresentation) = x.stabilizer
