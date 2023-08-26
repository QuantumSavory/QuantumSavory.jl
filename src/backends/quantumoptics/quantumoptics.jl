import QuantumOpticsBase
import QuantumOpticsBase: GenericBasis, CompositeBasis,
    StateVector, AbstractSuperOperator, Ket, Operator,
    basisstate, spinup, spindown, sigmap, sigmax, sigmay, sigmaz, destroy,
    projector, identityoperator, embed, dm, expect, ptrace, spre, spost
import QuantumOptics
import QuantumOptics: timeevolution

const QOR = QuantumOpticsRepr()

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

default_repr(::StateVector) = QOR
default_repr(::Operator) = QOR

traceout!(s::StateVector, i) = ptrace(s,i)
traceout!(s::Operator, i) = ptrace(s,i)

ispadded(::StateVector) = false
ispadded(::Operator) = false

function observable(state::Union{<:Ket,<:Operator}, indices, operation)
    operation = express(operation, QOR)
    e = basis(state)==basis(operation)
    op = e ? operation : embed(basis(state), indices, operation)
    expect(op, state)
end

function project_traceout!(state::Union{Ket,Operator},stateindex,psis::Union{Tuple{ZBasisState, ZBasisState},Vector{<:Ket}})
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

const _l = copy(express(Z1, QuantumOpticsRepr()))
function newstate(::Qubit,::QuantumOpticsRepr)
    copy(_l)
end
function newstate(::Qubit,::QuantumMCRepr)
    copy(_l)
end
const _vac = copy(express(F0, QuantumOpticsRepr()))
function newstate(::Qumode,::QuantumOpticsRepr)
    copy(_vac)
end
function newstate(::Qumode,::QuantumMCRepr)
    copy(_vac)
end

include("should_upstream.jl")
include("express.jl")
include("uptotime.jl")
include("noninstant.jl")
