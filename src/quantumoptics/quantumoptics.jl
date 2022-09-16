import QuantumOpticsBase
import QuantumOpticsBase: GenericBasis, CompositeBasis, StateVector, basisstate, spinup, spindown, sigmap, sigmax, sigmay, sigmaz, projector, identityoperator, embed, dm, expect, ptrace
import QuantumOptics

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

ispadded(::StateVector) = false
ispadded(::Operator) = false

function observable(state::Union{<:Ket,<:Operator}, indices, operation) # TODO union with QO.Operator
    operation = express(operation, QuantumOpticsRepresentation())
    e = basis(state)==basis(operation)
    op = e ? operation : embed(basis(state), indices, operation)
    expect(op, state)
end

function apply!(state::Ket, indices, operation)
    op = basis(state)==basis(operation) ? operation : embed(basis(state), indices, operation)
    state.data = (op*state).data
    state
end

function apply!(state::Operator, indices, operation)
    op = basis(state)==basis(operation) ? operation : embed(basis(state), indices, operation)
    state.data = (op*state*op').data
    state
end

function uptotime!(state::StateVector, idx::Int, background, Δt)
    state = isa(state, StateVector) ? dm(state) : state # AAA make more elegant with multiple dispatch
    uptotime!(state, idx, background, Δt)
end

function uptotime!(state::Operator, idx::Int, background, Δt)
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

function project_traceout!(state::Union{Ket,Operator},stateindex,basis::Symbolic{Operator})
    project_traceout!(state::Operator,stateindex,eigvecs(basis))
end

function project_traceout!(state::Union{Ket,Operator},stateindex,psis::Vector{<:Symbolic{Ket}})
    if nsubsystems(state) == 1 # TODO is there a way to do this in a single function, instead of _overlap vs _project_and_drop
        _overlaps = [_overlap(psi,state) for psi in psis]
        branch_probs = cumsum(_overlaps)
        @assert branch_probs[end] ≈ 1.0
        j = findfirst(>=(rand()), branch_probs) # TODO what if there is numerical imprecision and sum<1
        j, nothing
    else
        results = [_project_and_drop(state,psi,stateindex) for psi in psis]
        probs = [_branch_prob(r) for r in results]
        branch_probs = cumsum(probs)
        @assert branch_probs[end] ≈ 1.0
        j = findfirst(>=(rand()), branch_probs) # TODO what if there is numerical imprecision and sum<1
        j, normalize(results[j])
    end
end

##

apply!(state::Ket,      indices, operation::Symbolic{Operator}) = apply!(state, indices, express(operation, QOR))
apply!(state::Operator, indices, operation::Symbolic{Operator}) = apply!(state, indices, express(operation, QOR))

_overlap(l::Symbolic{Ket}, r::Ket) = _overlap(express(l, QOR), r)
_overlap(l::Symbolic{Ket}, r::Operator) = _overlap(express(l, QOR), r)

_project_and_drop(state::Ket, project_on::Symbolic{Ket}, basis_index) = _project_and_drop(state, express(project_on, QOR), basis_index)
_project_and_drop(state::Operator, project_on::Symbolic{Ket}, basis_index) = _project_and_drop(state, express(project_on, QOR), basis_index)




#express(r,i,state) = express_qo(state) # TODO implement other formats

#= TODO implement superoperators
apply!(state::Ket, indices, dep::Gates.Depolarize) = apply!(dm(state), indices, dep)
function apply!(state::Operator{B,B,D}, indices, dep::Gates.Depolarize) where {B<:CompositeBasis, D}
    filler_indices = [i for i in 1:nsubsystems(state) if i∉indices]
    ptr_state = ptrace(state, indices)
    dep_state = embed(basis(state), filler_indices, ptr_state) # TODO optimize
    return dep.p*state + (1-dep.p)/(size(state,1)/size(ptr_state,1))*dep_state
end
function apply!(state::Operator, indices, dep::Gates.Depolarize) # used for singular bases
    state.data .= dep.p .* state.data .+ (1-dep.p) ./ size(state.data,1) .* I(size(state.data,1))
    state
end
=#

## backgrounds
function krausops(T1::T1Decay, Δt)
    p = exp(-Δt/T1.t1) # TODO check this
    [√(1-p) * _lh, √p * _hh + _ll]
end

function krausops(T2::T2Dephasing, Δt)
    p = exp(-Δt/T2.t2) # TODO check this
    [√(1-p) * _z, √p * _id]
end

function newstate(::Qubit,::QuantumOpticsRepresentation)
    copy(_l)
end
function newstate(::Qubit,::QuantumMCRepresentation)
    copy(_l)
end

include("should_upstream.jl")
include("express.jl")
