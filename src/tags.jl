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

Base.getindex(tag::Tag, i::Int) = SumTypes.unwrap(tag)[i]
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
