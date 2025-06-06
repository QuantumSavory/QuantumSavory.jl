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
    # TODO if indices is ascending 1:n we can skip this embed -- such an improvement should be upstreamed to QuantumOpticsBase, so that embed is faster
    # TODO if nsubsystems(state) == 1 the embed should still work and be a no-op -- this should be upstreamed to QuantumInterface
    op = if nsubsystems(state) == 1
        operation
    else
        if nsubsystems(state) == length(indices) && 1:length(indices) == indices
            operation
        else
            embed(basis(state), indices, operation)
        end
    end
    expect(op, state)
end

# special case for projectors in order to avoid the overhead of an outer product
function observable(state::Union{<:Ket,<:Operator}, indices::Base.AbstractVecOrTuple{Int}, proj::SProjector)
    projket = express(proj.ket, QOR)
    if nsubsystems(projket) == length(indices) == nsubsystems(state)
        1:length(indices) != indices && (projket = permutesystems(projket, indices))
        return _observable(state, projket)
    else # TODO this branch still uses an outer product because we do not have a convenient contraction operation implemented when the dimensions differ
        return observable(state, indices, express(proj, QOR))
    end
end

_observable(a::Ket,b::Ket) = abs2(a'*b)
_observable(a::Operator,b::Ket) = expect(a,b)
_observable(a::Operator,b::Operator) = expect(a,b)

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
