module QSymbolics

using ..QuantumSavory: AbstractRepresentation, AbstractUse

using Symbolics
import Symbolics: simplify
using SymbolicUtils
import SymbolicUtils: Symbolic, _isone, flatten_term, isnotflat, Chain, Fixpoint
using TermInterface
import TermInterface: istree, exprhead, operation, arguments, similarterm, metadata

using LinearAlgebra
import LinearAlgebra: eigvecs

import QuantumOpticsBase
import QuantumOpticsBase: tensor, ⊗, basis, Ket, Bra, Operator, SuperOperator, Basis, SpinBasis, projector # TODO make QuantumInterface
import QuantumOptics
import QuantumClifford
import QuantumClifford: MixedDestabilizer, Stabilizer, @S_str

export SymQObj,QObj,
       ⊗,
       X,Y,Z,σˣ,σʸ,σᶻ,
       H,CNOT,CPHASE,
       X1,X2,Y1,Y2,Z1,Z2,X₁,X₂,Y₁,Y₂,Z₁,Z₂,
       SProjector,MixedState,IdentityOp,StabilizerState,@S_str

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

"""Pretty printer helper for subscript indices"""
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
# Metadata cache helpers
##

const CacheType = Dict{Tuple{<:AbstractRepresentation,<:AbstractUse},Any}
mutable struct Metadata
    express_cache::CacheType # TODO use more efficient mapping
end
Metadata() = Metadata(CacheType())

"""Decorate a struct definition in order to add a metadata dict which would be storing cached `express` results."""
macro withmetadata(strct)
    withmetadata(strct)
end
function withmetadata(strct)
    @assert strct.head == :struct
    struct_name = strct.args[2]
    constructor = :($struct_name() = new())
    if struct_name isa Expr # if Struct{T<:QObj} <: Symbolic{T}
        struct_name = struct_name.args[1]
        constructor = :($struct_name() = new())
        if struct_name isa Expr # if Struct{T<:QObj}
            struct_name = struct_name.args[1] # now it is just Struct
            constructor = :($struct_name{S}() where S = new{S}())
        end
    end
    struct_args = strct.args[end].args
    if all(x->x isa Symbol || x isa LineNumberNode || x.head==:(::), struct_args)
        # add constructor
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
        Base.@__doc__ $strct
        metadata(x::$struct_name)=x.metadata
    end)
end
function newwithmetadata(expr::Expr)
    if expr.head==:call && (expr.args[1]==:new || expr.args[1]==:(new{S}))
        push!(expr.args, :(Metadata()))
    else
        newwithmetadata.(expr.args)
    end
end
newwithmetadata(x) = x

##
# Basic Types
##

const QObj = Union{Ket,Operator,SuperOperator}
const SymQObj = Symbolic{<:QObj}
Base.:(-)(x::SymQObj) = (-1)*x
Base.:(-)(x::SymQObj,y::SymQObj) = x + (-y)

function Base.isequal(x::X,y::Y) where {X<:SymQObj, Y<:SymQObj}
    if X==Y
        if istree(x)
            if operation(x)==operation(y)
                ax,ay = arguments(x),arguments(y)
                (length(ax) == length(ay)) && all(zip(ax,ay)) do xy isequal(xy...) end
            else
                false
            end
        else
            propsequal(x,y)
        end
    else
        false
    end
end

# TODO check that this does not cause incredibly bad runtime performance
# use a macro to provide specializations if that is indeed the case
propsequal(x,y) = all(n->getproperty(x,n)==getproperty(y,n), propertynames(x))

##
# Most symbolic objects defined here
##

include("basic_ops_homogeneous.jl")
include("basic_ops_inhomogeneous.jl")
include("predefined.jl")
include("predefined_CPTP.jl")

##
# Symbolic and simplification rules
##

include("rules.jl")

##
# Latex printing
##

# TODO use Latexify for these
Base.show(io::IO, ::MIME"text/latex", x::SymQObj) = print(io, x)
Base.show(io::IO, x::SymQObj) = print(io,x)

end
