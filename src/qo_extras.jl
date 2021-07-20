using QuantumOptics # Should be import

# TODO should be in quantumoptics
function _drop_singular_bases(ket::Ket)
    b = tensor([b for b in basis(ket).bases if length(b)>1]...)
    return Ket(b, ket.data)
end
function _drop_singular_bases(op::Operator)
    b = tensor([b for b in basis(op).bases if length(b)>1]...)
    return QuantumOptics.Operator(b, op.data)
end

_branch_prob(psi::Ket) = norm(psi)^2
_branch_prob(op::Operator) = real(sum((op.data[i, i] for i in 1:size(op.data,1))))
overlap(l::Ket, r::Ket) = abs2(l'*r)
overlap(l::Ket, op::Operator) = real(l'*op*l)

# TODO should be in quantumoptics
function _project_and_drop(state::Ket, project_on, basis_index)
    singularbasis = GenericBasis(1)
    singularket = basisstate(singularbasis,1)
    proj = projector(singularket, project_on')
    basis_r = collect(Any,basis(state).bases)
    basis_l = copy(basis_r)
    basis_l[basis_index] = singularbasis
    emproj = embed(tensor(basis_l...),tensor(basis_r...),basis_index,proj)
    result = emproj*state
    return _drop_singular_bases(result)
end
function _project_and_drop(state::QuantumOptics.Operator, project_on, basis_index)
    singularbasis = GenericBasis(1)
    singularket = basisstate(singularbasis,1)
    proj = projector(singularket, project_on')
    basis_r = collect(Any,basis(state).bases)
    basis_l = copy(basis_r)
    basis_l[basis_index] = singularbasis
    emproj = embed(tensor(basis_l...),tensor(basis_r...),basis_index,proj)
    result = emproj*state*emproj'
    return _drop_singular_bases(result)
end

#todo Superoperator⊗Superoperator
#todo skraus(krausops)

# Defined here, needed for QuantumOptics

nsubsystems(s::Ket) = nsubsystems(s.basis)
function nsubsystems(s::Operator)
    @assert s.basis_l == s.basis_r
    nsubsystems(s.basis_l)
end
nsubsystems(b::CompositeBasis) = length(b.bases)
nsubsystems(b::Basis) = 1

subsystemcompose(states::Ket...) = tensor(states...)
subsystemcompose(ops::Operator...) = tensor(ops...)
subsystemcompose(k::Ket, op::Operator) = tensor(dm(k),op) # TODO this should be more general
subsystemcompose(op::Operator, k::Ket) = tensor(op,dm(k)) # TODO this should be more general

traceout!(s::StateVector, i) = ptrace(s,i)
traceout!(s::Operator, i) = ptrace(s,i)

function observable(state::QuantumOptics.Ket, indices, operation) # TODO union with QO.Operator
    e = isa(state,CompositeBasis) # TODO make this more elegant with multiple dispatch
    op = e ? operation : embed(basis(state), indices, operation)
    expect(op, state)
end

function observable(state::QuantumOptics.Operator, indices, operation)
    e = isa(state,CompositeBasis) # TODO make this more elegant with multiple dispatch
    op = e ? operation : embed(basis(state), indices, operation)
    expect(op, state)
end

function apply!(state::QuantumOptics.Ket, indices, operation)
    op = basis(state)==basis(operation) ? operation : embed(basis(state), indices, operation)
    state.data = (op*state).data
    state
end

function apply!(state::QuantumOptics.Operator, indices, operation)
    op = basis(state)==basis(operation) ? operation : embed(basis(state), indices, operation)
    state.data = (op*state*op').data
    state
end

function uptotime!(state, idx::Int, background, Δt)
    state = isa(state, QuantumOptics.StateVector) ? dm(state) : state # AAA make more elegant with multiple dispatch
    nstate = zero(state)
    tmpl = zero(state)
    tmpr = zero(state)
    b = basis(state)
    e = isa(b,CompositeBasis) # TODO make this more elegant with multiple dispatch
    for k in krausops(background, Δt)
        k = e ? embed(b,[idx],k) : k
        mul!(tmpl,k,state,1,0) # TODO there must be a prettier way to do this
        mul!(tmpr,tmpl,k',1,0)
        nstate.data .+= tmpr.data
    end
    @assert abs(tr(nstate)) ≈ 1. # TODO remove
    nstate
end

##
const _b2 = SpinBasis(1//2)
const _l = spinup(_b2)
const _h = spindown(_b2) # TODO is this a good decision... look at how clumsy the kraus ops are
const _s₊ = (_l+_h)/√2
const _s₋ = (_l-_h)/√2
const _lh = sigmap(_b2)
const _ll = projector(_l)
const _hh = projector(_h)
const _id = identityoperator(_b2)
const _z = sigmaz(_b2)
const _x = sigmax(_b2)
const _y = sigmay(_b2)
const _Id = identityoperator(_b2)
const _hadamard = (sigmaz(_b2)+sigmax(_b2))/√2
const _cnot = _ll⊗_Id + _hh⊗_x
const _cphase = _ll⊗_Id + _hh⊗_z

apply!(state::QuantumOptics.Ket,      indices, operation::Gates.AbstractUGate) = apply!(state, indices, express_qo(operation))
apply!(state::QuantumOptics.Operator, indices, operation::Gates.AbstractUGate) = apply!(state, indices, express_qo(operation))

overlap(l::States.AbstractState, r::QuantumOptics.Ket) = overlap(express_qo(l), r)
overlap(l::States.AbstractState, r::QuantumOptics.Operator) = overlap(express_qo(l), r)

_project_and_drop(state::QuantumOptics.Ket, project_on::States.AbstractState, basis_index) = _project_and_drop(state, express_qo(project_on), basis_index)
_project_and_drop(state::QuantumOptics.Operator, project_on::States.AbstractState, basis_index) = _project_and_drop(state, express_qo(project_on), basis_index)

express_qo(::Gates.HGate) = _hadamard
express_qo(::Gates.XGate) = _x
express_qo(::Gates.YGate) = _y
express_qo(::Gates.ZGate) = _z
express_qo(::Gates.CPHASEGate) = _cphase
express_qo(::Gates.CNOTGate) = _cnot

express_qo(s::States.XState) = (_s₊,_s₋)[s.subspace+1]
express_qo(s::States.ZState) = (_l,_h)[s.subspace+1]

apply!(state::QuantumOptics.Ket, indices, dep::Gates.Depolarize) = apply!(dm(state), indices, dep)
function apply!(state::QuantumOptics.Operator{B,B,D}, indices, dep::Gates.Depolarize) where {B<:CompositeBasis, D}
    filler_indices = [i for i in 1:nsubsystems(state) if i∉indices]
    ptr_state = ptrace(state, indices)
    dep_state = embed(basis(state), filler_indices, ptr_state) # TODO optimize
    return dep.p*state + (1-dep.p)/(size(state,1)/size(ptr_state,1))*dep_state
end
function apply!(state::QuantumOptics.Operator, indices, dep::Gates.Depolarize) # used for singular bases
    state.data .= dep.p .* state.data .+ (1-dep.p) ./ size(state.data,1) .* I(size(state.data,1))
    state
end

## backgrounds
function krausops(T1::T1Decay, Δt)
    p = exp(-Δt/T1.t1) # TODO check this
    [√(1-p) * _lh, √p * _hh + _ll]
end

function krausops(T2::T2Dephasing, Δt)
    p = exp(-Δt/T2.t2) # TODO check this
    [√(1-p) * _z, √p * _id]
end
