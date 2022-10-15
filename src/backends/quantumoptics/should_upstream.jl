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

using QuantumOpticsBase: LazyTensor, AbstractSuperOperator

abstract type AbstractLazySuperOperator{B1,B2} <: AbstractSuperOperator{B1,B2} end

struct LazyPrePost{B,DT} <: AbstractLazySuperOperator{Tuple{B,B},Tuple{B,B}}
    preop::Union{Operator{B,B,DT},Nothing}
    postop::Union{Operator{B,B,DT},Nothing}
    function LazyPrePost(preop::T,postop::T) where {B,DT,T<:Union{Operator{B,B,DT},Nothing}}
        new{B,DT}(preop,postop)
    end
end

struct LazySuperSum{B,F,T} <: AbstractLazySuperOperator{Tuple{B,B},Tuple{B,B}}
    basis::B
    factors::F
    sops::T
end

QuantumOpticsBase.basis(sop::LazyPrePost) = basis(sop.preop)
QuantumOpticsBase.basis(sop::LazySuperSum) = sop.basis
QuantumOpticsBase.embed(bl,br,index,op::LazyPrePost) = LazyPrePost(embed(bl,br,index,op.preop),embed(bl,br,index,op.postop))
function Base.:(*)(sop::LazyPrePost, op::Operator)
    # TODO do not create the spre and spost objects, do it without intermediaries, do it in place with buffers
    r = op
    if !isnothing(sop.preop)
        r = spre(sop.preop)*r
    end
    if !isnothing(sop.postop)
        r = spost(sop.postop)*r
    end
    r
end
Base.:(*)(l::LazyPrePost, r::LazyPrePost) = LazyPrePost(l.preop*r.preop, r.postop*l.postop)
Base.:(+)(ops::LazyPrePost...) = LazySuperSum(basis(first(ops)),fill(1,length(ops)),ops)
QuantumOpticsBase.embed(bl,br,index,op::LazySuperSum) = LazySuperSum(bl, op.factors, [embed(bl,br,index,o) for o in op.sops])
function Base.:(*)(ssop::LazySuperSum, op::Operator)
    res = zero(op)
    for (f,sop) in zip(ssop.factors,ssop.sops)
        res += f*(sop*op)
    end
    res
end
