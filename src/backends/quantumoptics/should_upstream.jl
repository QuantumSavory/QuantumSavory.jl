function _drop_singular_bases(ket::Ket)
    b = tensor([b for b in basis(ket).bases if length(b)>1]...)
    return Ket(b, ket.data)
end
function _drop_singular_bases(op::Operator)
    b = tensor([b for b in basis(op).bases if length(b)>1]...)
    return Operator(b, op.data)
end

_branch_prob(psi::Ket) = norm(psi)^2
_branch_prob(op::Operator) = real(sum((op.data[i, i] for i in 1:size(op.data,1))))
_overlap(l::Ket, r::Ket) = abs2(l'*r)
_overlap(l::Ket, op::Operator) = real(l'*op*l)

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
function _project_and_drop(state::Operator, project_on, basis_index)
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


QuantumSymbolics.express(s::Union{<:Ket,<:Operator}, ::QuantumOpticsRepr) = s
