const TagElementTypes = Union{Symbol, Int, DataType}

"""
Tags are used to represent classical metadata describing the state (or even history) of nodes and their registers. The library allows the construction of custom tags using the `Tag` constructor. Currently tags are implemented as instances of a [sum type](https://github.com/MasonProtter/SumTypes.jl) and have fairly constrained structure. Most of them are constrained to contain only Symbol instances and integers.

Here is an example of such a generic tag:

```jldoctest
julia> Tag(:sometagdescriptor, 1, 2, -3)
SymbolIntIntInt(:sometagdescriptor, 1, 2, -3)::Tag
```

A tag can have a custom `DataType` as first argument, in which case additional customizability in printing is available. E.g. consider the [`EntanglementHistory`] tag used to track how pairs were entangled before a swap happened.

```jldoctest
julia> using QuantumSavory.ProtocolZoo: EntanglementHistory

julia> Tag(EntanglementHistory, 1, 2, 3, 4, 5)
Was entangled to 1.2, but swapped with .5 which was entangled to 3.4
```

See also: [`tag!`](@ref), [`query`](@ref)
"""
@sum_type Tag :hidden begin
    Symbol(::Symbol)
    SymbolInt(::Symbol, ::Int)
    SymbolIntInt(::Symbol, ::Int, ::Int)
    SymbolIntIntInt(::Symbol, ::Int, ::Int, ::Int)
    SymbolIntIntIntInt(::Symbol, ::Int, ::Int, ::Int, ::Int)
    SymbolIntIntIntIntInt(::Symbol, ::Int, ::Int, ::Int, ::Int, ::Int)
    SymbolIntIntIntIntIntInt(::Symbol, ::Int, ::Int, ::Int, ::Int, ::Int, ::Int)
    Type(::DataType)
    TypeInt(::DataType, ::Int)
    TypeIntInt(::DataType, ::Int, ::Int)
    TypeIntIntInt(::DataType, ::Int, ::Int, ::Int)
    TypeIntIntIntInt(::DataType, ::Int, ::Int, ::Int, ::Int)
    TypeIntIntIntIntInt(::DataType, ::Int, ::Int, ::Int, ::Int, ::Int)
    TypeIntIntIntIntIntInt(::DataType, ::Int, ::Int, ::Int, ::Int, ::Int, ::Int)
    TypeSymbol(::DataType, ::Symbol)
    TypeSymbolInt(::DataType, ::Symbol, ::Int)
    TypeSymbolIntInt(::DataType, ::Symbol, ::Int, ::Int)
    Forward(::Tag, ::Int)
end

"""Tag types available in the taggging and tag-querying system.

See also: [`query`](@ref), [`tag!`](@ref), [`Wildcard`](@ref)"""
const tag_types = Tag'

Base.@propagate_inbounds Base.getindex(tag::Tag, i::Int) = SumTypes.unwrap(tag).data[i]
Base.length(tag::Tag) = length(SumTypes.unwrap(tag).data)
Base.iterate(tag::Tag, state=1) = state > length(tag) ? nothing : (SumTypes.unwrap(tag)[state],state+1)

function SumTypes.show_sumtype(io::IO, x::Tag)
    data = SumTypes.unwrap(x)
    sym = SumTypes.get_name(data)
    if length(data.data) == 0
        print(io, String(sym), "::Tag")
    else
        if data[1] isa DataType && data[1]!==Int
            print(io, data[1](data[2:length(x)]...))
        else
            print(io, String(sym), '(', join((repr(field) for field ∈ data), ", "), ")::Tag")
        end
    end
end

Base.convert(::Type{Tag}, x::Tag) = x
Base.convert(::Type{Tag}, x) = Tag(x)

# Create a constructor for each tag variant
for (tagsymbol, tagvariant) in pairs(tag_types)
    sig = methods(tagvariant)[1].sig.parameters[2:end]
    args = (:a, :b, :c, :d, :e, :f, :g)[1:length(sig)]
    argssig = [:($a::$t) for (a,t) in zip(args, sig)]
    eval(quote function Tag($(argssig...))
        ($tagvariant)($(args...))
    end end)
end
