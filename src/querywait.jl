# TODO weird ordering of what should be kwargs due to https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/135
@resumable function _query_wait(sim, reg::Register, locked::Union{Nothing,Bool}, assigned::Union{Nothing,Bool}, args...)
    q = query(reg, args...; locked, assigned)
    while isnothing(q)
        @yield onchange_tag(reg)
        q = query(reg, args...; locked, assigned)
    end
    return q
end
function query_wait(store::Register, args...; locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing)
    # TODO weird ordering of what should be kwargs due to https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/135
    return @process _query_wait(get_time_tracker(store), store, locked, assigned, args...)
end

@resumable function _query_wait(sim, mb::MessageBuffer, args...)
    q = query(mb, args...)
    while isnothing(q)
        @yield wait(mb)
        q = query(mb, args...)
    end
    return q
end
function query_wait(store::MessageBuffer, args...)
    return @process _query_wait(get_time_tracker(store), store, args...)
end

@resumable function _querydelete_wait(sim, mb::Register, locked::Union{Nothing,Bool}, assigned::Union{Nothing,Bool}, args...)
    q = querydelete!(mb, args...; locked, assigned)
    while isnothing(q)
        @yield onchange_tag(mb)
        q = querydelete!(mb, args...; locked, assigned)
    end
    return q
end
function querydelete_wait!(store::Register, args...; locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing)
    return @process _querydelete_wait(get_time_tracker(store), store, locked, assigned, args...)
end

@resumable function _querydelete_wait(sim, mb::MessageBuffer, args...)
    q = querydelete!(mb, args...)
    while isnothing(q)
        @yield wait(mb)
        q = querydelete!(mb, args...)
    end
    return q
end
function querydelete_wait!(store::MessageBuffer, args...)
    return @process _querydelete_wait(get_time_tracker(store), store, args...)
end
