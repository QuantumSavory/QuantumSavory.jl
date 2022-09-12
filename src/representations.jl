import SymbolicUtils: Symbolic

function express(state::Symbolic, repr::T) where {T<:AbstractRepresentation}
    if false # is in metadata
        # get from metadata
    else
        # record in metadata
        return express_from_cache(express_nolookup(state, repr))
    end
end
express(s::Number, repr::AbstractRepresentation) = s
express(state::Symbolic) = express(state, default_representation(state))
express(state) = state
express_from_cache(cache) = cache

express_nolookup(state, ::QuantumMCRepresentation) = express_nolookup(state, QuantumOpticsRepresentation())

function consistent_expression(regs,idx,state)
    reprs = Set([r.reprs[i] for (r,i) in zip(regs,idx)])
    if length(reprs)>1
        error("no way to choose yet")
    end
    pop!(reprs)
end

default_repr(::Qubit) = QuantumOpticsRepresentation()
