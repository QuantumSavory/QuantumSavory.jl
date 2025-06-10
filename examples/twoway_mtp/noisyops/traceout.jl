import QuantumSavory

# """ DEPRECATED
# Perform a projective measurement on the given slot of the given register.
# with the given noise parameter ξ.

# `project_traceout!(reg, slot, [stateA, stateB]; ξ)` performs a projective measurement,
# projecting on either `stateA` or `stateB`, returning the index of the subspace
# on which the projection happened or the opposite subspace with probability ξ.
# It assumes the list of possible states forms a basis for the Hilbert space. 
# The Hilbert space of the register is automatically shrunk.

# A basis object can be specified on its own as well, e.g.
# `project_traceout!(reg, slot, basis; ξ)`.
# """
# function project_traceout!(r::QuantumSavory.RegRef, basis; time=nothing, ξ::Float64=0.0, rng::AbstractRNG=Random.GLOBAL_RNG)
#     result = QuantumSavory.project_traceout!(r, basis; time=time)
#     if rand(rng) < ξ
#         result = (result % 2) + 1
#     end
#     return result
# end

_overlap(E::Operator, r::Ket) = real(r'*E*r)
_overlap(E::Operator, ρ::Operator) = real(tr(E * ρ))

function QuantumSavory._project_and_drop(state::Ket, project_on::Operator, basis_index)
    singularbasis = GenericBasis(1)
    singularket = basisstate(singularbasis,1)
    proj = project_on   # Not Correct
    basis_r = collect(Any,basis(state).bases)
    basis_l = copy(basis_r)
    basis_l[basis_index] = singularbasis
    emproj = embed(tensor(basis_l...),tensor(basis_r...),basis_index,proj)
    result = emproj*state
    return QuantumSavory._drop_singular_bases(result)
end
function QuantumSavory._project_and_drop(state::Operator, project_on::Operator, basis_index)
    singularbasis = GenericBasis(1)
    singularket = basisstate(singularbasis,1)
    proj = project_on   # Not Correct
    basis_r = collect(Any,basis(state).bases)
    basis_l = copy(basis_r)
    basis_l[basis_index] = singularbasis
    emproj = embed(tensor(basis_l...),tensor(basis_r...),basis_index,proj)
    result = emproj*state*emproj'
    return QuantumSavory._drop_singular_bases(result)
end

function QuantumSavory.project_traceout!(state::Union{Ket,Operator},stateindex::Int,povms::Base.AbstractVecOrTuple{Operator})
    if nsubsystems(state) == 1 # TODO this case is exactly the same as the original code
        _overlaps = [_overlap(povm,state) for povm in povms]
        branch_probs = cumsum(_overlaps)
        if !(branch_probs[end] ≈ 1.0)
            throw("State not normalized. Could be due to passing wrong state to `initialize!`")
        end
        j = findfirst(>=(rand()), branch_probs)
        j, nothing
    else
        # results = [QuantumSavory._project_and_drop(state,povm,stateindex) for povm in povms]  # Not working
        # TODO: handle case with higher more than 1 subsystems
    end
end
