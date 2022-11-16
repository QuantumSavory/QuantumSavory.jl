struct SymQ{T<:QObj} <: Symbolic{T}
    name::Symbol
    basis::Basis # From QuantumOpticsBase # TODO make QuantumInterface
end
istree(::SymQ) = false
metadata(::SymQ) = nothing
basis(x::SymQ) = x.basis

const SKet = SymQ{Ket}
Base.print(io::IO, x::SKet) = print(io, "|$(x.name)⟩")
const SOperator = SymQ{Operator}
Base.print(io::IO, x::SOperator) = print(io, "$(x.name)")

@withmetadata struct SScaled{T<:QObj} <: Symbolic{T}
    coeff
    obj
    SScaled{S}(c,k) where S = _isone(c) ? k : new{S}(c,k)
end
istree(::SScaled) = true
arguments(x::SScaled) = [x.coeff, x.obj]
operation(x::SScaled) = *
Base.:(*)(c, x::Symbolic{T}) where {T<:QObj} = SScaled{T}(c,x)
Base.:(*)(x::Symbolic{T}, c) where {T<:QObj} = SScaled{T}(c,x)
Base.:(/)(x::Symbolic{T}, c) where {T<:QObj} = SScaled{T}(1/c,x)
basis(x::SScaled) = basis(x.obj)

const SScaledKet = SScaled{Ket}
function Base.print(io::IO, x::SScaledKet)
    if x.coeff isa Number
        print(io, "$(x.coeff)$(x.obj)")
    else
        print(io, "($(x.coeff))$(x.obj)")
    end
end
const SScaledOperator = SScaled{Operator}
function Base.print(io::IO, x::SScaledOperator)
    if x.coeff isa Number
        print(io, "$(x.coeff)$(x.obj)")
    else
        print(io, "($(x.coeff))$(x.obj)")
    end
end

@withmetadata struct SAdd{T<:QObj} <: Symbolic{T}
    dict
    SAdd{S}(d) where S = length(d)==1 ? SScaled{S}(reverse(first(d))...) : new{S}(d)
end
istree(::SAdd) = true
arguments(x::SAdd) = [SScaledKet(v,k) for (k,v) in pairs(x.dict)]
operation(x::SAdd) = +
Base.:(+)(xs::Vararg{Symbolic{T},N}) where {T<:QObj,N} = SAdd{T}(countmap_flatten(xs, SScaled{T}))
Base.:(+)(xs::Vararg{Symbolic{<:QObj},0}) = 0 # to avoid undefined type parameters issue in the above method
basis(x::SAdd) = basis(first(x.dict).first)

const SAddKet = SAdd{Ket}
Base.print(io::IO, x::SAddKet) = print(io, "("*join(map(string, arguments(x)),"+")::String*")") # type assert to help inference
const SAddOperator = SAdd{Operator}
Base.print(io::IO, x::SAddOperator) = print(io, "("*join(map(string, arguments(x)),"+")::String*")") # type assert to help inference

@withmetadata struct STensor{T<:QObj} <: Symbolic{T}
    terms
    function STensor{S}(terms) where S
        coeff, cleanterms = prefactorscalings(terms)
        coeff * new{S}(cleanterms)
    end
end
istree(::STensor) = true
arguments(x::STensor) = x.terms
operation(x::STensor) = ⊗
⊗(xs::Symbolic{T}...) where {T<:QObj} = STensor{T}(collect(xs))
basis(x::STensor) = tensor(basis.(x.terms)...)

const STensorKet = STensor{Ket}
Base.print(io::IO, x::STensorKet) = print(io, join(map(string, arguments(x)),""))
const STensorOperator = STensor{Operator}
Base.print(io::IO, x::STensorOperator) = print(io, join(map(string, arguments(x)),"⊗"))
