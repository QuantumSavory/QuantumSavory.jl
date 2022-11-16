const _qc_l = MixedDestabilizer(S"Z")
const _qc_h = MixedDestabilizer(S"-Z")
const _qc_s₊ = MixedDestabilizer(S"X")
const _qc_s₋ = MixedDestabilizer(S"-X")
const _qc_i₊ = MixedDestabilizer(S"Y")
const _qc_i₋ = MixedDestabilizer(S"-Y")

express_nolookup(s::XBasisState, ::CliffordRepr) = (_qc_s₊,_qc_s₋)[s.idx]
express_nolookup(s::YBasisState, ::CliffordRepr) = (_qc_i₊,_qc_i₋)[s.idx]
express_nolookup(s::ZBasisState, ::CliffordRepr) = (_qc_l,_qc_h)[s.idx]
function express_nolookup(s::Symbolic{T}, repr::CliffordRepr) where {T<:Union{Ket,Operator}}
    if istree(s) && operation(s)==⊗
        #operation(s)(express.(arguments(s), (repr,))...) # TODO this does not work because QuantumClifford.⊗ is different from ⊗
        QuantumClifford.tensor(express.(arguments(s), (repr,))...)
    else
        error("Encountered an object $(s) of type $(typeof(s)) that can not be converted to $(repr) representation") # TODO make a nice error type
    end
end

express_nolookup(::CPHASEGate,       ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sCPHASE
express_nolookup(::CNOTGate,         ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sCNOT
express_nolookup(::XGate,            ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sX
express_nolookup(::ZGate,            ::CliffordRepr, ::UseAsOperation) = QuantumClifford.sZ
express_nolookup(x::STensorOperator,r::CliffordRepr,u::UseAsOperation) = QCGateSequence([express(t,r,u) for t in x.terms])

function project_traceout!(state::QuantumClifford.MixedDestabilizer,stateindex,basis::Symbolic{Operator})
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
express_nolookup(op::QuantumClifford.PauliOperator, ::CliffordRepr, ::UseAsObservable) = op
express_nolookup(op::STensorOperator, r::CliffordRepr, u::UseAsObservable) = QuantumClifford.tensor(express.(arguments(op),(r,),(u,))...)
express_nolookup(::XGate, ::CliffordRepr, ::UseAsObservable) = QuantumClifford.P"X"
express_nolookup(::YGate, ::CliffordRepr, ::UseAsObservable) = QuantumClifford.P"Y"
express_nolookup(::ZGate, ::CliffordRepr, ::UseAsObservable) = QuantumClifford.P"Z"
express_nolookup(op::SScaledOperator, r::CliffordRepr, u::UseAsObservable) = arguments(op)[1] * express(arguments(op)[2],r,u)
express_nolookup(op, ::CliffordRepr, ::UseAsObservable) = error("Can not convert $(op) into a `PauliOperator`, which is the only observable that can be computed for QuantumClifford objects. Consider defining `express_nolookup(op, ::CliffordRepr, ::UseAsObservable)::PauliOperator` for this object.")

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
    nqubits = isa(x.basis, CompositeBasis) ? length(x.basis.bases) : 1
    # TODO assert all are qubits
    one(MixedDestabilizer,0,nqubits)
end
express_nolookup(x::SProjector, repr::CliffordRepr) = express_nolookup(x.ket, repr)
express_nolookup(x::StabilizerState, ::CliffordRepr) = copy(x.stabilizer)
