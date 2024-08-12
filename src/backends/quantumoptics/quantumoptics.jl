import QuantumOpticsBase
import QuantumOpticsBase: GenericBasis, CompositeBasis,
    StateVector, AbstractSuperOperator, Ket, Operator,
    basisstate, spinup, spindown, sigmap, sigmax, sigmay, sigmaz, destroy,
    projector, identityoperator, embed, dm, expect, ptrace, spre, spost
import QuantumOptics
import QuantumOptics: timeevolution
import QuantumInterface: nsubsystems

const QOR = QuantumOpticsRepr()

subsystemcompose(states::Ket...) = tensor(states...)
subsystemcompose(ops::Operator...) = tensor(ops...)
subsystemcompose(k::Ket, op::Operator) = tensor(dm(k),op) # TODO this should be more general
subsystemcompose(op::Operator, k::Ket) = tensor(op,dm(k)) # TODO this should be more general

default_repr(::StateVector) = QOR
default_repr(::Operator) = QOR

ispadded(::StateVector) = false
ispadded(::Operator) = false

function observable(state::Union{<:Ket,<:Operator}, indices::Base.AbstractVecOrTuple{Int}, operation)
    operation = express(operation, QOR)
    e = basis(state)==basis(operation)
    op = e ? operation : embed(basis(state), indices, operation)
    expect(op, state)
end

function project_traceout!(state::Union{Ket,Operator},stateindex::Int,psis::Base.AbstractVecOrTuple{Ket})
    if nsubsystems(state) == 1 # TODO is there a way to do this in a single function, instead of _overlap vs _project_and_drop
        _overlaps = [_overlap(psi,state) for psi in psis]
        branch_probs = cumsum(_overlaps)
        if !(branch_probs[end] ≈ 1.0)
            throw("State not normalized. Could be due to passing wrong state to `initialize!`")
        end
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
