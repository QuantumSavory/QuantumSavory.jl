function _enforce_tag_cap!(slot::RegRef, max_per_slot::Union{Int,Nothing}, tagtype::DataType, pattern...)
    isnothing(max_per_slot) && return nothing
    max_per_slot < 0 && throw(ArgumentError("max_per_slot must be nonnegative"))
    tags = queryall(slot, tagtype, pattern...; filo=false)
    for tag in Iterators.take(tags, max(0, length(tags) - max_per_slot))
        untag!(slot, tag.id)
    end
    return nothing
end

function _enforce_delete_cap!(slot::RegRef, node::Int, max_delete_per_slot::Union{Int,Nothing})
    return _enforce_tag_cap!(slot, max_delete_per_slot, EntanglementDelete, ❓, node, slot.idx, ❓, ❓)
end

function _enforce_history_cap!(slot::RegRef, max_history_per_slot::Union{Int,Nothing})
    return _enforce_tag_cap!(slot, max_history_per_slot, EntanglementHistory, ❓, ❓, ❓, ❓, ❓, ❓, ❓)
end
