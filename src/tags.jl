export tags

@sum_type Tag :hidden begin
    Symbol(::Symbol)
    SymbolInt(::Symbol, ::Int)
    SymbolIntInt(::Symbol, ::Int, ::Int)
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
