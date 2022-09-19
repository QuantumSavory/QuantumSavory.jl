using Symbolics
import Symbolics: simplify
using SymbolicUtils
import SymbolicUtils: Symbolic, _isone, flatten_term, isnotflat, Chain, Fixpoint
using TermInterface
import TermInterface: istree, exprhead, operation, arguments, similarterm, metadata

using LinearAlgebra
import LinearAlgebra: eigvecs

import QuantumOpticsBase
import QuantumOpticsBase: tensor, ⊗, basis, Ket, Bra, Operator, Basis, SpinBasis, projector # TODO make QuantumInterface
import QuantumOptics
import QuantumClifford
import QuantumClifford: MixedDestabilizer, Stabilizer, @S_str

function countmap(samples) # A simpler version of StatsBase.countmap, because StatsBase is slow to import
    counts = Dict{Any,Any}()
    for s in samples
        counts[s] = get(counts, s, 0)+1
    end
    counts
end

function countmap_flatten(samples, flattenhead)
    counts = Dict{Any,Any}()
    for s in samples
        if istree(s) && s isa flattenhead # TODO Could you use the TermInterface `operation` here instead of `flattenhead`?
            coef, term = arguments(s)
            counts[term] = get(counts, term, 0)+coef
        else
            counts[s] = get(counts, s, 0)+1
        end
    end
    counts
end

function num_to_sub(n::Int)
    str = string(n)
    replace(str,
        "1"=>"₁",
        "2"=>"₂",
        "3"=>"₃",
        "4"=>"₄",
        "5"=>"₅",
        "6"=>"₆",
        "7"=>"₇",
        "8"=>"₈",
        "9"=>"₉",
        "0"=>"₀",
    )
end

##

const CacheType = Dict{Tuple{<:AbstractRepresentation,<:AbstractUse},Any}
mutable struct Metadata
    express_cache::CacheType # TODO use more efficient mapping
end
Metadata() = Metadata(CacheType())
macro withmetadata(strct)
    withmetadata(strct)
end
function withmetadata(strct)
    @assert strct.head == :struct
    struct_name = strct.args[2]
    if struct_name isa Expr
        struct_name = struct_name.args[1]
    end
    struct_args = strct.args[end].args
    if all(x->x isa Symbol || x isa LineNumberNode || x.head==:(::), struct_args)
        # add constructor
        constructor = :($struct_name() = new())
        args = [x for x in struct_args if x isa Symbol || x isa Expr]
        append!(constructor.args[1].args, args)
        append!(constructor.args[end].args[end].args, args)
        push!(constructor.args[end].args[end].args, :(Metadata()))
        push!(struct_args, constructor)
    else
        # modify constructor
        newwithmetadata.(struct_args)
    end
    # add metadata slot
    push!(struct_args, :(metadata::Metadata))
    esc(quote
        $strct
        metadata(x::$struct_name)=x.metadata
    end)
end
function newwithmetadata(expr::Expr)
    if expr.head==:call && expr.args[1]==:new
        push!(expr.args, :(Metadata()))
    else
        newwithmetadata.(expr.args)
    end
end
newwithmetadata(x) = x

##

struct SKet <: Symbolic{Ket}
    name::Symbol
    basis::Basis # From QuantumOpticsBase # TODO make QuantumInterface
end
istree(::SKet) = false
metadata(::SKet) = nothing
Base.print(io::IO, x::SKet) = print(io, "|$(x.name)⟩")
basis(x::SKet) = x.basis

struct SBra <: Symbolic{Bra}
    name::Symbol
    basis::Basis # From QuantumOpticsBase # TODO make QuantumInterface
end
istree(::SBra) = false
metadata(::SBra) = nothing
Base.print(io::IO, x::SBra) = print(io, "⟨$(x.name)|")
basis(x::SBra) = x.basis

struct SOperator <: Symbolic{Operator}
    name::Symbol
    basis::Basis # From QuantumOpticsBase # TODO make QuantumInterface
end
istree(::SOperator) = false
metadata(::SOperator) = nothing
Base.print(io::IO, x::SOperator) = print(io, "$(x.name)")
basis(x::SOperator) = x.basis

@withmetadata struct SScaledKet <: Symbolic{Ket}
    coeff
    ket
    SScaledKet(c,k) = _isone(c) ? k : new(c,k)
end
istree(::SScaledKet) = true
arguments(x::SScaledKet) = [x.coeff, x.ket]
operation(x::SScaledKet) = *
Base.:(*)(c, x::Symbolic{Ket}) = SScaledKet(c,x)
Base.:(*)(x::Symbolic{Ket}, c) = SScaledKet(c,x)
Base.:(/)(x::Symbolic{Ket}, c) = SScaledKet(1/c,x)
function Base.print(io::IO, x::SScaledKet)
    if x.coeff isa Number
        print(io, "$(x.coeff)$(x.ket)")
    else
        print(io, "($(x.coeff))$(x.ket)")
    end
end
basis(x::SScaledKet) = basis(x.ket)

@withmetadata struct SScaledBra <: Symbolic{Bra}
    coeff
    bra
    SScaledBra(c,k) = _isone(c) ? k : new(c,k)
end
istree(::SScaledBra) = true
arguments(x::SScaledBra) = [x.coeff, x.bra]
operation(x::SScaledBra) = *
Base.:(*)(c, x::Symbolic{Bra}) = SScaledBra(c,x)
Base.:(*)(x::Symbolic{Bra}, c) = SScaledBra(c,x)
Base.:(/)(x::Symbolic{Bra}, c) = SScaledBra(1/c,x)
function Base.print(io::IO, x::SScaledBra)
    if x.coeff isa Number
        print(io, "$(x.coeff)$(x.bra)")
    else
        print(io, "($(x.coeff))$(x.bra)")
    end
end
basis(x::SScaledBra) = basis(x.bra)

@withmetadata struct SScaledOperator <: Symbolic{Operator}
    coeff
    operator
    SScaledOperator(c,k) = _isone(c) ? k : new(c,k)
end
istree(::SScaledOperator) = true
arguments(x::SScaledOperator) = [x.coeff, x.operator]
operation(x::SScaledOperator) = *
Base.:(*)(c, x::Symbolic{Operator}) = SScaledOperator(c,x)
Base.:(*)(x::Symbolic{Operator},c) = SScaledOperator(c,x)
Base.:(/)(x::Symbolic{Operator}, c) = SScaledOperator(1/c,x)
function Base.print(io::IO, x::SScaledOperator)
    if x.coeff isa Number
        print(io, "$(x.coeff)$(x.operator)")
    else
        print(io, "($(x.coeff))$(x.operator)")
    end
end
basis(x::SScaledOperator) = basis(x.operator)

@withmetadata struct SAddKet <: Symbolic{Ket}
    dict
    SAddKet(d) = length(d)==1 ? SScaledKet(first(d)...) : new(d)
end
istree(::SAddKet) = true
arguments(x::SAddKet) = [SScaledKet(v,k) for (k,v) in pairs(x.dict)]
operation(x::SAddKet) = +
Base.:(+)(xs::Symbolic{Ket}...) = SAddKet(countmap_flatten(xs, SScaledKet))
Base.print(io::IO, x::SAddKet) = print(io, join(map(string, arguments(x)),"+"))
basis(x::SAddKet) = basis(first(x.dict).first)

@withmetadata struct SAddBra <: Symbolic{Bra}
    dict
    SAddBra(d) = length(d)==1 ? SScaledBra(first(d)...) : new(d)
end
istree(::SAddBra) = true
arguments(x::SAddBra) = [SScaledBra(v,k) for (k,v) in pairs(x.dict)]
operation(x::SAddBra) = +
Base.:(+)(xs::Symbolic{Bra}...) = SAddBra(countmap_flatten(xs, SScaledBra))
Base.print(io::IO, x::SAddBra) = print(io, join(map(string, arguments(x)),"+"))
basis(x::SAddBra) = basis(first(x.dict).first)

@withmetadata struct SAddOperator <: Symbolic{Operator}
    dict
    SAddOperator(d) = length(d)==1 ? SScaledOperator(first(d)...) : new(d)
end
istree(::SAddOperator) = true
arguments(x::SAddOperator) = [SScaledOperator(v,k) for (k,v) in pairs(x.dict)]
operation(x::SAddOperator) = +
Base.:(+)(xs::Symbolic{Operator}...) = SAddOperator(countmap_flatten(xs, SScaledOperator))
Base.print(io::IO, x::SAddOperator) = print(io, join(map(string, arguments(x)),"+"))
basis(x::SAddOperator) = basis(first(x.dict).first)

@withmetadata struct STensorKet <: Symbolic{Ket}
    terms
    function STensorKet(terms)
        coeff, cleanterms = prefactorscalings(terms)
        coeff * new(cleanterms)
    end
end
istree(::STensorKet) = true
arguments(x::STensorKet) = x.terms
operation(x::STensorKet) = ⊗
⊗(xs::Symbolic{Ket}...) = STensorKet(collect(xs))
Base.print(io::IO, x::STensorKet) = print(io, join(map(string, arguments(x)),""))
basis(x::STensorKet) = tensor(basis.(x.terms)...)

@withmetadata struct STensorBra <: Symbolic{Bra}
    terms
    function STensorBra(terms)
        coeff, cleanterms = prefactorscalings(terms)
        coeff * new(cleanterms)
    end
end
istree(::STensorBra) = true
arguments(x::STensorBra) = x.terms
operation(x::STensorBra) = ⊗
⊗(xs::Symbolic{Bra}...) = STensorBra(collect(xs))
Base.print(io::IO, x::STensorBra) = print(io, join(map(string, arguments(x)),""))
basis(x::STensorBra) = tensor(basis.(x.terms)...)

@withmetadata struct STensorOperator <: Symbolic{Operator}
    terms
    function STensorOperator(terms)
        coeff, cleanterms = prefactorscalings(terms)
        coeff * new(cleanterms)
    end
end
istree(::STensorOperator) = true
arguments(x::STensorOperator) = x.terms
operation(x::STensorOperator) = ⊗
⊗(xs::Symbolic{Operator}...) = STensorOperator(collect(xs))
Base.print(io::IO, x::STensorOperator) = print(io, join(map(string, arguments(x)),"⊗"))
basis(x::STensorOperator) = tensor(basis.(x.terms)...)

@withmetadata struct SApplyKet <: Symbolic{Ket}
    op
    ket
end
istree(::SApplyKet) = true
arguments(x::SApplyKet) = [x.op,x.ket]
operation(x::SApplyKet) = *
Base.:(*)(op::Symbolic{Operator}, k::Symbolic{Ket}) = SApplyKet(op,k)
Base.print(io::IO, x::SApplyKet) = begin print(io, x.op); print(io, x.ket) end
basis(x::SApplyKet) = basis(x.ket)

@withmetadata struct SApplyBra <: Symbolic{Bra}
    bra
    op
end
istree(::SApplyBra) = true
arguments(x::SApplyBra) = [x.bra,x.op]
operation(x::SApplyBra) = *
Base.:(*)(b::Symbolic{Bra}, op::Symbolic{Operator}) = SApplyBra(b,op)
Base.print(io::IO, x::SApplyBra) = begin print(io, x.bra); print(io, x.op) end
basis(x::SApplyBra) = basis(x.bra)

@withmetadata struct SBraKet <: Symbolic{Complex}
    bra
    op
    ket
end
istree(::SBraKet) = true
arguments(x::SBraKet) = [x.bra,x.op,x.ket]
operation(x::SBraKet) = *
Base.:(*)(b::Symbolic{Bra}, op::Symbolic{Operator}, k::Symbolic{Ket}) = SBraKet(b,op,k)
function Base.print(io::IO, x::SBraKet)
    if isnothing(x.op)
        print(io,string(x.bra)[1:end-1])
        print(io,x.ket)
    else
        print(io.x.bra)
        print(io.x.op)
        print(io.x.ket)
    end
end

Base.show(io::IO, x::Symbolic{Ket}) = print(io,x)
Base.show(io::IO, x::Symbolic{Bra}) = print(io,x)
Base.show(io::IO, x::Symbolic{Operator}) = print(io,x)

function hasscalings(xs)
    any(xs) do x
        operation(x) == *
    end
end

""" Used to perform (a*|k⟩) ⊗ (b*|l⟩) → (a*b) * (|k⟩⊗|l⟩) """
function prefactorscalings(xs)
    terms = []
    coeff = 1::Any
    for x in xs
        if istree(x) && operation(x) == *
            c,t = arguments(x)
            coeff *= c
            push!(terms,t)
        else
            push!(terms,x)
        end
    end
    coeff, terms
end

function prefactorscalings_rule(xs)
    coeff, terms = prefactorscalings(xs)
    coeff * ⊗(terms...)
end

function isnotflat_precheck(*)
    function (x)
        operation(x) === (*) || return false
        args = arguments(x)
        for t in args
            if istree(t) && operation(t) === (*)
                return true
            end
        end
        return false
    end
end

FLATTEN_RULES = [
    @rule(~x::isnotflat_precheck(⊗) => flatten_term(⊗, ~x)),
    @rule ⊗(~~xs::hasscalings) => prefactorscalings_rule(xs)
]

tensor_simplify = Fixpoint(Chain(FLATTEN_RULES))

##

abstract type SpecialKet <: Symbolic{Ket} end
istree(::SpecialKet) = false
basis(x::SpecialKet) = x.basis

@withmetadata struct XBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::XBasisState) = print(io, "|X$(num_to_sub(x.idx))⟩")

@withmetadata struct YBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::YBasisState) = print(io, "|Y$(num_to_sub(x.idx))⟩")

@withmetadata struct ZBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::ZBasisState) = print(io, "|Z$(num_to_sub(x.idx))⟩")

@withmetadata struct FockBasisState <: SpecialKet
    idx::Int
    basis::Basis
end
Base.print(io::IO, x::FockBasisState) = print(io, "|$(num_to_sub(x.idx))⟩")

@withmetadata struct DiscreteCoherentState <: SpecialKet
    alpha::Number # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::DiscreteCoherentState) = print(io, "|$(x.alpha)⟩")

@withmetadata struct ContinuousCoherentState <: SpecialKet
    alpha::Number # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::ContinuousCoherentState) = print(io, "|$(x.alpha)⟩")

@withmetadata struct MomentumEigenState <: SpecialKet
    p::Number # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::MomentumEigenState) = print(io, "|δₚ($(x.p))⟩")

@withmetadata struct PositionEigenState <: SpecialKet
    x::Float64 # TODO parameterize
    basis::Basis
end
Base.print(io::IO, x::PositionEigenState) = print(io, "|δₓ($(x.x))⟩")

const qubit_basis = SpinBasis(1//2)
const X1 = X₁ = XBasisState(1, qubit_basis)
const X2 = X₂ = XBasisState(2, qubit_basis)
const Y1 = Y₁ = YBasisState(1, qubit_basis)
const Y2 = Y₂ = YBasisState(2, qubit_basis)
const Z1 = Z₁ = ZBasisState(1, qubit_basis)
const Z2 = Z₂ = ZBasisState(2, qubit_basis)

##

abstract type AbstractSingleQubitGate <: Symbolic{Operator} end
abstract type AbstractTwoQubitGate <: Symbolic{Operator} end
istree(::AbstractSingleQubitGate) = false
istree(::AbstractTwoQubitGate) = false
basis(::AbstractSingleQubitGate) = SpinBasis(1//2)
basis(::AbstractTwoQubitGate) = SpinBasis(1//2)⊗SpinBasis(1//2)

@withmetadata struct OperatorEmbedding <: Symbolic{Operator}
    gate::Symbolic{Operator} # TODO parameterize
    indices::Vector{Int}
    basis::Basis
end
istree(::OperatorEmbedding) = true

@withmetadata struct XGate <: AbstractSingleQubitGate end
eigvecs(g::XGate) = [X1,X2]
Base.print(io::IO, x::XGate) = print(io, "X̂")
@withmetadata struct YGate <: AbstractSingleQubitGate end
eigvecs(g::YGate) = [Y1,Y2]
Base.print(io::IO, x::YGate) = print(io, "Ŷ")
@withmetadata struct ZGate <: AbstractSingleQubitGate end
eigvecs(g::ZGate) = [Z1,Z2]
Base.print(io::IO, x::ZGate) = print(io, "Ẑ")
@withmetadata struct HGate <: AbstractSingleQubitGate end
Base.print(io::IO, x::HGate) = print(io, "Ĥ")
@withmetadata struct CNOTGate <: AbstractTwoQubitGate end
Base.print(io::IO, x::CNOTGate) = print(io, "ĈNOT")
@withmetadata struct CPHASEGate <: AbstractTwoQubitGate end
Base.print(io::IO, x::CPHASEGate) = print(io, "ĈPHASE")

const X = XGate()
const Y = YGate()
const Z = ZGate()
const H = HGate()
const CNOT = CNOTGate()
const CPHASE = CPHASEGate()

##

@withmetadata struct SProjector <: Symbolic{Operator}
    ket::Symbolic{Ket} # TODO parameterize
end
istree(::SProjector) = true
arguments(x::SProjector) = [x.ket]
operation(x::SProjector) = projector
QuantumOptics.projector(x::Symbolic{Ket}) = SProjector(x)
basis(x::SProjector) = basis(x.ket)
function Base.print(io::IO, x::SProjector)
    print(io,"𝐏[")
    print(io,x.ket)
    print(io,"]")
end

@withmetadata struct MixedState <: Symbolic{Operator}
    basis::Basis # From QuantumOpticsBase # TODO make QuantumInterface
end
MixedState(x::Symbolic{Ket}) = MixedState(basis(x))
MixedState(x::Symbolic{Operator}) = MixedState(basis(x))
istree(::MixedState) = false
basis(x::MixedState) = x.basis
Base.print(io::IO, x::MixedState) = print(io, "𝕄")

@withmetadata struct StabilizerState <: Symbolic{Ket}
    stabilizer::MixedDestabilizer
end
function StabilizerState(x::Stabilizer)
    r,c = size(x)
    @assert r==c
    StabilizerState(MixedDestabilizer(x))
end
istree(::StabilizerState) = false
basis(x::StabilizerState) = SpinBasis(1//2)^QuantumClifford.nqubits(x.stabilizer)
Base.print(io::IO, x::StabilizerState) = print(io, "𝒮$(num_to_sub(QuantumClifford.nqubits(x.stabilizer)))")
