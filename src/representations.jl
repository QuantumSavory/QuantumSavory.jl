export express

import SymbolicUtils: Symbolic

function express(state::Symbolic, repr::AbstractRepresentation, use::AbstractUse)
    md = metadata(state)
    isnothing(md) && return express_from_cache(express_nolookup(state, repr, use))
    if haskey(md.express_cache,(repr,use))
        return express_from_cache(md.express_cache[(repr,use)])
    else
        cache = express_nolookup(state, repr, use)
        md.express_cache[(repr,use)] = cache
        return express_from_cache(cache)
    end
end

express(s::Number, repr::AbstractRepresentation, use::AbstractUse) = s

# Assume two-argument express statements are for "as state" representations.
express(s, repr::AbstractRepresentation) = express(s, repr, UseAsState())

# Default to the two-argument expression unless overwritten
express_nolookup(x, repr::AbstractRepresentation, ::AbstractUse) = express_nolookup(x, repr)

# The two-argument expression is the AsState one
express_nolookup(x, repr::AbstractRepresentation, ::UseAsState) = express_nolookup(x, repr)

# Most of the time the cache is exactly the expression we need,
# but we need indirection to be able to implement cases
# where the cache is a distribution over possible samples.
express_from_cache(cache) = cache

function consistent_representation(regs,idx,state)
    reprs = Set([r.reprs[i] for (r,i) in zip(regs,idx)])
    if length(reprs)>1
        error("no way to choose yet")
    end
    pop!(reprs)
end

default_repr(::Qubit) = QuantumOpticsRepr()
express(state::Symbolic) = express(state, QuantumOpticsRepr())
express(state) = state

#TODO
express_nolookup(state, ::QuantumMCRepr) = express_nolookup(state, QuantumOpticsRepr())

function apply!(state, indices, operation::Symbolic{Operator})
    repr = default_repr(state)
    apply!(state, indices, express(operation, repr, UseAsOperation()))
end

function apply!(state, indices, operation::Symbolic{SuperOperator})
    repr = default_repr(state)
    apply!(state, indices, express(operation, repr, UseAsOperation()))
end
