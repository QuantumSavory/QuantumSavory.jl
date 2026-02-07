# TODO weird ordering of what should be kwargs due to https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/135
@resumable function _query_wait(sim, reg::Register, on, locked::Union{Nothing,Bool}, assigned::Union{Nothing,Bool}, args...)
    q = query(reg, args...; locked, assigned)
    while isnothing(q)
        @yield onchange(reg, on)
        q = query(reg, args...; locked, assigned)
    end
    return q
end
function query_wait(store::Register, args...; on::Type{Tag}=Tag, locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing)
    # TODO weird ordering of what should be kwargs due to https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/135
    return @process _query_wait(get_time_tracker(store), store, on, locked, assigned, args...)
end

@resumable function _query_wait(sim, mb::MessageBuffer, on, args...)
    q = query(mb, args...)
    while isnothing(q)
        @yield onchange(mb, on)
        q = query(mb, args...)
    end
    return q
end
function query_wait(store::MessageBuffer, args...; on::Type{Tag}=Tag)
    return @process _query_wait(get_time_tracker(store), store, on, args...)
end

@resumable function _querydelete_wait(sim, mb::Register, on, locked::Union{Nothing,Bool}, assigned::Union{Nothing,Bool}, args...)
    q = querydelete!(mb, args...; locked, assigned)
    while isnothing(q)
        @yield onchange(mb, on)
        q = querydelete!(mb, args...; locked, assigned)
    end
    return q
end
function querydelete_wait!(store::Register, args...; on::Type{Tag}=Tag, locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing)
    return @process _querydelete_wait(get_time_tracker(store), store, on, locked, assigned, args...)
end

@resumable function _querydelete_wait(sim, mb::MessageBuffer, on, args...)
    q = querydelete!(mb, args...)
    while isnothing(q)
        @yield onchange(mb, on)
        q = querydelete!(mb, args...)
    end
    return q
end
function querydelete_wait!(store::MessageBuffer, args...; on::Type{Tag}=Tag)
    return @process _querydelete_wait(get_time_tracker(store), store, on, args...)
end
