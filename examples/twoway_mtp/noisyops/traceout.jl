import QuantumSavory

function _project(state::Ket, proj::Operator, basis_index::Int)
    _project(dm(state), proj, basis_index)
end
function _project(state::Operator, proj::Operator, basis_index::Int)
    b0 = basis(state)
    emproj = embed(b0, b0, basis_index, proj)
    state * emproj
end

QuantumSavory._overlap(l::Operator, r::Ket) = real(r' * l * r)
QuantumSavory._overlap(l::Operator, r::Operator) = nothing

# function QuantumSavory.project_traceout!(state::Ket, stateindex::Int, povms::Base.AbstractVecOrTuple{Operator})
#     error("Not implemented")
# end
function QuantumSavory.project_traceout!(state, stateindex::Int, povms::Base.AbstractVecOrTuple{Operator})
    if nsubsystems(state) == 1
        _overlaps = [QuantumSavory._overlap(povm,state) for povm in povms]
        branch_probs = cumsum(_overlaps)
        if !(branch_probs[end] ≈ 1.0)
            throw("State not normalized. Could be due to passing wrong state to `initialize!`")
        end
        j = findfirst(>=(rand()), branch_probs)
        j, nothing
    else
        results = [_project(state,povm,stateindex) for povm in povms]
        probs = [QuantumSavory._branch_prob(r) for r in results]
        branch_probs = cumsum(probs)
        @assert branch_probs[end] ≈ 1.0
        j = findfirst(>=(rand()), branch_probs)
        # TODO: drop the base
        j, normalize(results[j])
    end
end