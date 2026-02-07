"""
$TYPEDSIGNATURES

A convenience function that combines waiting (via [`onchange`](@ref)) and querying (via [`query`](@ref)) in a loop,
returning a ConcurrentSim process that yields the first successful query result.

This replaces the common pattern of:

```julia
while true
    @yield onchange(register, Tag)
    result = query(register, :my_tag, ❓)
    if !isnothing(result)
        # do something with result
        break
    end
end
```

with the much simpler:

```julia
result = @yield query_wait(register, :my_tag, ❓)
# do something with result
```

The `on` keyword argument is passed to [`onchange`](@ref) to control what type of events are waited on.
The `locked` and `assigned` keyword arguments are passed through to [`query`](@ref) for register queries.

```jldoctest
julia> using ResumableFunctions; using ConcurrentSim;

julia> reg = Register(5);
       net = RegisterNet([reg]);
       env = get_time_tracker(net);

julia> @resumable function sender(env, reg)
           @yield timeout(env, 1.0)
           tag!(reg[1], :my_tag, 42)
       end;

julia> LOG = [];

julia> @resumable function receiver(env, reg)
           result = @yield query_wait(reg, :my_tag, ❓)
           push!(LOG, result)
       end;

julia> @process sender(env, reg);

julia> @process receiver(env, reg);

julia> run(env, 0.5);

julia> length(LOG)
0

julia> run(env, 1.5);

julia> length(LOG)
1

julia> LOG[1].tag
SymbolInt(:my_tag, 42)::Tag
```

See also: [`query`](@ref), [`querydelete_wait!`](@ref), [`onchange`](@ref), [`tag!`](@ref)
"""
function query_wait end

# TODO weird ordering of what should be kwargs due to https://github.com/JuliaDynamics/ResumableFunctions.jl/issues/135
@resumable function _query_wait(sim, reg::Register, on, locked::Union{Nothing,Bool}, assigned::Union{Nothing,Bool}, args...)
    q = query(reg, args...; locked, assigned)
    while isnothing(q)
        @yield onchange(reg, on)
        q = query(reg, args...; locked, assigned)
    end
    return q
end
function query_wait(store::Register, args...; on=Any, locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing)
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
function query_wait(store::MessageBuffer, args...; on=Any)
    return @process _query_wait(get_time_tracker(store), store, on, args...)
end

"""
$TYPEDSIGNATURES

A convenience function that combines waiting (via [`onchange`](@ref)) and querying-with-deletion (via [`querydelete!`](@ref)) in a loop,
returning a ConcurrentSim process that yields the first successful query result (deleting the matched entry).

This replaces the common pattern of:

```julia
while true
    @yield onchange(store, Tag)
    result = querydelete!(store, :my_tag, ❓)
    if !isnothing(result)
        # do something with result
        break
    end
end
```

with the much simpler:

```julia
result = @yield querydelete_wait!(store, :my_tag, ❓)
# do something with result
```

The `on` keyword argument is passed to [`onchange`](@ref) to control what type of events are waited on.
The `locked` and `assigned` keyword arguments are passed through to [`querydelete!`](@ref) for register queries.

```jldoctest
julia> using ResumableFunctions; using ConcurrentSim;

julia> net = RegisterNet([Register(3), Register(2)]);
       env = get_time_tracker(net);

julia> @resumable function sender(env)
           @yield timeout(env, 1.0)
           put!(channel(net, 1=>2), Tag(:my_tag))
           @yield timeout(env, 2.0)
           put!(channel(net, 1=>2), Tag(:second_tag, 123, 456))
       end;

julia> LOG = [];

julia> @resumable function receiver(env)
           mb = messagebuffer(net, 2)
           msg = @yield querydelete_wait!(mb, :second_tag, ❓, ❓)
           push!(LOG, msg)
       end;

julia> @process sender(env);

julia> @process receiver(env);

julia> run(env, 2.0);

julia> length(LOG)
0

julia> run(env, 4.0);

julia> length(LOG)
1

julia> LOG[1].tag
SymbolIntInt(:second_tag, 123, 456)::Tag
```

See also: [`querydelete!`](@ref), [`query_wait`](@ref), [`onchange`](@ref), [`tag!`](@ref)
"""
function querydelete_wait! end

@resumable function _querydelete_wait(sim, mb::Register, on, locked::Union{Nothing,Bool}, assigned::Union{Nothing,Bool}, args...)
    q = querydelete!(mb, args...; locked, assigned)
    while isnothing(q)
        @yield onchange(mb, on)
        q = querydelete!(mb, args...; locked, assigned)
    end
    return q
end
function querydelete_wait!(store::Register, args...; on=Any, locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing)
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
function querydelete_wait!(store::MessageBuffer, args...; on=Any)
    return @process _querydelete_wait(get_time_tracker(store), store, on, args...)
end
