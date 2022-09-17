const _qc_l = MixedDestabilizer(S"Z")
const _qc_h = MixedDestabilizer(S"-Z")
const _qc_s₊ = MixedDestabilizer(S"X")
const _qc_s₋ = MixedDestabilizer(S"-X")
const _qc_i₊ = MixedDestabilizer(S"Y")
const _qc_i₋ = MixedDestabilizer(S"-Y")

express_nolookup(s::XBasisState, ::CliffordRepr) = (_qc_s₊,_qc_s₋)[s.idx]
express_nolookup(s::YBasisState, ::CliffordRepr) = (_qc_i₊,_qc_i₋)[s.idx]
express_nolookup(s::ZBasisState, ::CliffordRepr) = (_qc_l,_qc_h)[s.idx]

express_nolookup(::CPHASEGate,       ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sCPHASE
express_nolookup(::CNOTGate,         ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sCNOT
express_nolookup(::XGate,            ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sX
express_nolookup(::ZGate,            ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sZ
express_nolookup(x::STensorOperator,r::CliffordRepr,u::UseAsOperation) = QCGateSequence([express(t,r,u) for t in x.terms])

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

struct QCRandomSampler # TODO specify types
    operators # union of QCRandomSampler and MixedDestabilizer
    weights
end
function express_nolookup(x::SAddOperator, repr::CliffordRepr)
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
function express_nolookup(x::MixedState, ::CliffordRepr)
    nqubits = length(x.basis.bases)
    # TODO assert all are qubits
    one(MixedDestabilizer,0,nqubits)
end
express_nolookup(x::SProjector, repr::CliffordRepr) = express_nolookup(x.ket, repr)
express_nolookup(x::StabilizerState, ::CliffordRepr) = copy(x.stabilizer)
