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
