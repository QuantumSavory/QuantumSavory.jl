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
    TypeSymbol(::DataType, ::Symbol)
    TypeSymbolInt(::DataType, ::Symbol, ::Int)
    TypeSymbolIntInt(::DataType, ::Symbol, ::Int, ::Int)
end

"""Tag types available in the taggging and tag-querying system.

See also: [`query`](@ref), [`tag!`](@ref), [`Wildcard`](@ref)"""
const tag_types = Tag'

Base.getindex(tag::Tag, i::Int) = tag.data[i]
Base.length(tag::Tag) = length(tag.data.data)
Base.iterate(tag::Tag, state=1) = state > length(tag) ? nothing : (tag[state],state+1)
