macro domain(predicate)
    symbols = Set{Symbol}()

    function collect_value_symbols!(expression)
        if expression isa Symbol
            push!(symbols, expression)
        elseif expression isa Expr
            if expression.head ≡ :call
                foreach(collect_value_symbols!, @view expression.args[2:end])
            elseif expression.head ≡ :comparison
                foreach(collect_value_symbols!, @view expression.args[1:2:end])
            elseif expression.head ≢ :quote
                foreach(collect_value_symbols!, expression.args)
            end
        end
        return nothing
    end

    collect_value_symbols!(predicate)
    length(symbols) == 1 || throw(ArgumentError(
        "@domain requires a predicate with exactly one value symbol: `$(predicate)`",
    ))
    value = only(symbols)
    message = "$(value) must obey `$(predicate)`"
    return :($(esc(predicate)) || throw(DomainError($(esc(value)), $message)))
end
