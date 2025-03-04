struct QueryError <: Exception
    msg
    f
    q
end

function Base.showerror(io::IO, err::QueryError)
    print(io, "QueryError: ")
    println(io, err.msg)
    print(io, "  in function `$(err.f)` with query `$(err.q)`")
end

"""$TYPEDSIGNATURES

Assign a tag to a slot in a register.

See also: [`query`](@ref), [`untag!`](@ref)"""
function tag!(ref::RegRef, tag)
    tag = convert(Tag, tag)
    id = guid()
    push!(ref.reg.guids, id)
    ref.reg.tag_info[id] = (;tag, slot=ref.idx, time=now(get_time_tracker(ref)))
    unlock(ref.reg.tag_waiter[])
    return id
end

function peektags(ref::RegRef)
    [ref.reg.tag_info[i].tag for i in ref.reg.guids if ref.reg.tag_info[i].slot == ref.idx]
end

"""$TYPEDSIGNATURES

Remove the tag with the given id from a [`RegRef`](@ref) or a [`Register`](@ref).

To remove a tag based on a query, use [`querydelete!`](@ref) instead.

See also: [`querydelete!`](@ref), [`query`](@ref), [`tag!`](@ref)
"""
function untag!(ref::RegOrRegRef, id::Integer)
    reg = get_register(ref)
    i = findfirst(==(id), reg.guids)
    isnothing(i) ? throw(QueryError("Attempted to delete a nonexistent tag id", untag!, id)) : deleteat!(reg.guids, i) # TODO make sure there is a clear error message
    to_be_deleted = reg.tag_info[id]
    delete!(reg.tag_info, id)
    unlock(reg.tag_waiter[])
    return to_be_deleted
end

"""Wildcard type for use with the tag querying functionality.

Usually you simply want an instance of this type (available as the constant [`W`](@ref) or [`❓`](@ref)).

See also: [`query`](@ref), [`tag!`](@ref)"""
struct Wildcard end

const QueryTypes = Union{Function,Wildcard,TagElementTypes}

"""A wildcard instance for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`❓`](@ref)"""
const W = Wildcard()


"""A wildcard instance for use with the tag querying functionality.

This emoji can be inputted with the `\\:question:` emoji shortcut,
or you can simply use the ASCII alternative [`W`](@ref).

See also: [`query`](@ref), [`tag!`](@ref), [`W`](@ref)"""
const ❓ = W


"""
$TYPEDSIGNATURES

A query function that returns all slots of a register that have a given tag, with support for predicates and wildcards.

```jldoctest; filter = r"id = (\\d*), "
julia> r = Register(10);
       tag!(r[1], :symbol, 2, 3);
       tag!(r[2], :symbol, 4, 5);

julia> queryall(r, :symbol, ❓, ❓)
2-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 2, tag = SymbolIntInt(:symbol, 4, 5)::Tag)
 (slot = Slot 1, id = 1, tag = SymbolIntInt(:symbol, 2, 3)::Tag)

julia> queryall(r, :symbol, ❓, >(4))
1-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 2, tag = SymbolIntInt(:symbol, 4, 5)::Tag)

julia> queryall(r, :symbol, ❓, >(5))
@NamedTuple{slot::RegRef, id::Int128, tag::Tag}[]
```
"""
queryall(reg::RegOrRegRef, queryargs::Vararg{QueryTypes,N}; filo=true, kwargs...) where {N} = _query(reg, Val{true}(), Val{filo}(), queryargs...; kwargs...)
queryall(reg::RegOrRegRef, query::Tag; filo=true, kwargs...) = _query(reg, Val{true}(), Val{filo}(), query; kwargs...)
queryall(::MessageBuffer, queryargs...; kwargs...) = throw(ArgumentError("`queryall` does not currently support `MessageBuffer`, chiefly to encourage the use of `querydelete!` instead"))

"""
$TYPEDSIGNATURES

A query function searching for the first slot in a register that has a given tag.

Wildcards are supported (instances of `Wildcard` also available as the constants [`W`](@ref) or the emoji [`❓`](@ref) which can be entered as `\\:question:` in the REPL).
Predicate functions are also supported (they have to be `Int`↦`Bool` functions).
The order of query lookup can be specified in terms of FIFO or FILO and defaults to FILO if not specified.
The keyword arguments `locked` and `assigned` can be used to check, respectively,
whether the given slot is locked or whether it contains a quantum state.
The keyword argument `filo` can be used to specify whether the search should be done in a FIFO or FILO order,
defaulting to `filo=true` (i.e. a stack-like behavior).

```jldoctest; filter = r"id = (\\d*), "
julia> r = Register(10);
       tag!(r[1], :symbol, 2, 3);
       tag!(r[2], :symbol, 4, 5);


julia> query(r, :symbol, 4, 5)
(slot = Slot 2, id = 4, tag = SymbolIntInt(:symbol, 4, 5)::Tag)

julia> lock(r[1]);

julia> query(r, :symbol, 4, 5; locked=false) |> isnothing
false

julia> query(r, :symbol, ❓, 3)
(slot = Slot 1, id = 3, tag = SymbolIntInt(:symbol, 2, 3)::Tag)

julia> query(r, :symbol, ❓, 3; assigned=true) |> isnothing
true

julia> query(r, :othersym, ❓, ❓) |> isnothing
true

julia> tag!(r[5], Int, 4, 5);

julia> query(r, Float64, 4, 5) |> isnothing
true

julia> query(r, Int, 4, >(7)) |> isnothing
true

julia> query(r, Int, 4, <(7))
(slot = Slot 5, id = 5, tag = TypeIntInt(Int64, 4, 5)::Tag)
```

A [`query`](@ref) can be on on a single slot of a register:

```jldoctest; filter = r"id = (\\d*), "
julia> r = Register(5);

julia> tag!(r[2], :symbol, 2, 3);

julia> query(r[2], :symbol, 2, 3)
(slot = Slot 2, id = 6, tag = SymbolIntInt(:symbol, 2, 3)::Tag)

julia> query(r[3], :symbol, 2, 3) === nothing
true

julia> queryall(r[2], :symbol, 2, 3)
1-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 6, tag = SymbolIntInt(:symbol, 2, 3)::Tag)
```

See also: [`queryall`](@ref), [`tag!`](@ref), [`W`](@ref), [`❓`](@ref)
"""
function query(reg::RegOrRegRef, queryargs::Vararg{QueryTypes,N}; locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing, filo::Bool=true) where {N}
    _query(reg, Val{false}(), Val{filo}(), queryargs...; locked=locked, assigned=assigned)
end
query(reg::RegOrRegRef, query::Tag; locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing, filo::Bool=true) = _query(reg, Val{false}(), Val{filo}(), query; locked=locked, assigned=assigned)

"""
$TYPEDSIGNATURES

You are advised to actually use [`querydelete!`](@ref), not `query` when working with classical message buffers.
"""
function query(mb::MessageBuffer, queryargs::Vararg{QueryTypes,N}) where {N}
    for (depth, (src, tag)) in pairs(mb.buffer)
        query_good(tag, queryargs...) && return (;depth, src, tag)
    end
    return nothing
end

for i in 1:10 # Vararg{Union{...}, N} does not specialize well, so we are explicitly making a method for each number of arguments
    args = (:a, :b, :c, :d, :e, :f, :g, :h, :i, :j, :k, :l)[1:i]
    query_expr = quote
    function _query(reg::RegOrRegRef, ::Val{allB}, ::Val{filoB}, $(args...);
        locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing
    ) where {allB, filoB} # queryargs is so specifically typed in order to trigger the compiler heuristics for specialization, leading to very significant performance improvements
        ref = isa(reg, RegRef) ? reg : nothing
        reg = get_register(reg)
        res = NamedTuple{(:slot, :id, :tag), Tuple{RegRef, Int128, Tag}}[]
        l = length(reg.guids)
        indices = filoB ? (l:-1:1) : (1:l)
        for i in indices
            i = reg.guids[i]
            tag = reg.tag_info[i].tag
            slot = reg[reg.tag_info[i].slot]
            if _nothingor(ref, slot) && _nothingor(locked, islocked(slot)) && _nothingor(assigned, isassigned(slot))
                good = query_good(tag, $(args...))
                if good
                    allB ? push!(res, (slot=slot, id=i, tag=tag)) : return (slot=slot, id=i, tag=tag)
                end
            end
        end
        allB ? res : nothing
    end
    end
    #println(query_expr)
    eval(query_expr)
end

for i in 1:10
    vars = (:a, :b, :c, :d, :e, :f, :g, :h, :i, :j, :k, :l)
    VARS = (:A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K, :L)
    args = vars[1:i]
    checks = [:(query_check($(args[i]), $(VARS[i]))) for i in 1:i]
    composite_check = reduce((l,r)->:($l && $r), checks)
    cases = []
    for (symbol, variant) in pairs(Tag')
        signature = methods(variant)[1].sig.parameters[2:end]
        l = length(signature)
        sigargs = VARS[1:l]
        if l==i
            push!(cases, :($symbol($(sigargs...)) => $composite_check))
        else
        end
    end
    body_expr = isempty(cases) ? :(false) : quote
        @cases tag begin
            $(cases...)
            _ => false
        end
    end
    query_good_expr = quote
    @inline function query_good(tag::Tag, $(args...))
        $body_expr
    end
    end
    #println(query_good_expr)
    eval(query_good_expr)
end

@inline _nothingor(l,r) = isnothing(l) || l==r
@inline query_check(q::T, t::T) where {T<:TagElementTypes} = (q==t)::Bool
@inline query_check(q::Function, t) = q(t)::Bool
@inline query_check(_::Wildcard, _) = true
@inline query_check(_, _) = false

"""
$TYPEDSIGNATURES

A [`query`](@ref) for classical message buffers that also deletes the message out of the buffer.

```jldoctest
julia> net = RegisterNet([Register(3), Register(2)])
A network of 2 registers in a graph of 1 edges

julia> put!(channel(net, 1=>2), Tag(:my_tag));

julia> put!(channel(net, 1=>2), Tag(:another_tag, 123, 456));

julia> query(messagebuffer(net, 2), :my_tag)

julia> run(get_time_tracker(net))

julia> query(messagebuffer(net, 2), :my_tag)
(depth = 1, src = 1, tag = Symbol(:my_tag)::Tag)

julia> querydelete!(messagebuffer(net, 2), :my_tag)
@NamedTuple{src::Union{Nothing, Int64}, tag::Tag}((1, Symbol(:my_tag)::Tag))

julia> querydelete!(messagebuffer(net, 2), :my_tag) === nothing
true

julia> querydelete!(messagebuffer(net, 2), :another_tag, ❓, ❓)
@NamedTuple{src::Union{Nothing, Int64}, tag::Tag}((1, SymbolIntInt(:another_tag, 123, 456)::Tag))

julia> querydelete!(messagebuffer(net, 2), :another_tag, ❓, ❓) === nothing
true
```

You can also wait on a message buffer for a message to arrive before running a query:

```jldoctest
julia> using ResumableFunctions; using ConcurrentSim;

julia> net = RegisterNet([Register(3), Register(2), Register(3)])
A network of 3 registers in a graph of 2 edges

julia> env = get_time_tracker(net);

julia> @resumable function receive_tags(env)
           while true
               mb = messagebuffer(net, 2)
               @yield wait(mb)
               msg = querydelete!(mb, :second_tag, ❓, ❓)
               print("t=\$(now(env)): query returns ")
               if isnothing(msg)
                   println("nothing")
               else
                   println("\$(msg.tag) received from node \$(msg.src)")
               end
           end
       end
receive_tags (generic function with 1 method)

julia> @resumable function send_tags(env)
           @yield timeout(env, 1.0)
           put!(channel(net, 1=>2), Tag(:my_tag))
           @yield timeout(env, 2.0)
           put!(channel(net, 3=>2), Tag(:second_tag, 123, 456))
       end
send_tags (generic function with 1 method)

julia> @process send_tags(env);

julia> @process receive_tags(env);

julia> run(env, 10)
t=1.0: query returns nothing
t=3.0: query returns SymbolIntInt(:second_tag, 123, 456)::Tag received from node 3
```
"""
function querydelete!(mb::MessageBuffer, args...)
    r = query(mb, args...)
    return isnothing(r) ? nothing : popat!(mb.buffer, r.depth)
end

"""
$TYPEDSIGNATURES

A [`query`](@ref) for [`Register`](@ref) or a register slot (i.e. a [`RegRef`](@ref)) that also deletes the tag.

```jldoctest; filter = r"id = (\\d*), "
julia> reg = Register(3)
       tag!(reg[1], :tagA, 1, 2, 3)
       tag!(reg[2], :tagA, 10, 20, 30)
       tag!(reg[2], :tagB, 6, 7, 8);

julia> queryall(reg, :tagA, ❓, ❓, ❓)
2-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 2, id = 4, tag = SymbolIntIntInt(:tagA, 10, 20, 30)::Tag)
 (slot = Slot 1, id = 3, tag = SymbolIntIntInt(:tagA, 1, 2, 3)::Tag)

julia> querydelete!(reg, :tagA, ❓, ❓, ❓)
(slot = Slot 2, id = 4, tag = SymbolIntIntInt(:tagA, 10, 20, 30)::Tag)

julia> queryall(reg, :tagA, ❓, ❓, ❓)
1-element Vector{@NamedTuple{slot::RegRef, id::Int128, tag::Tag}}:
 (slot = Slot 1, id = 3, tag = SymbolIntIntInt(:tagA, 1, 2, 3)::Tag)
```
"""
function querydelete!(reg::RegOrRegRef, args...; kwa...)
    r = query(reg, args...; kwa...)
    isnothing(r) || untag!(r.slot, r.id)
    return r
end

tag!(tagcontainer, args...) = tag!(tagcontainer, Tag(args...))

function _query(reg::RegOrRegRef, ::Val{allB}, ::Val{filoB}, query::Tag; locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing) where {allB, filoB}
    ref = isa(reg, RegRef) ? reg : nothing
    reg = get_register(reg)
    res = NamedTuple{(:slot, :id, :tag), Tuple{RegRef, Int128, Tag}}[]
    l = length(reg.guids)
    indices = filoB ? (l:-1:1) : (1:l)
    for i in indices
        i = reg.guids[i]
        tag = reg.tag_info[i].tag
        slot = reg[reg.tag_info[i].slot]
        if _nothingor(ref, slot) && _nothingor(locked, islocked(slot)) && _nothingor(assigned, isassigned(slot)) && tag==query
            allB ? push!(res, (slot=slot, id=i, tag=tag)) : return (slot=slot, id=i, tag=tag)
        end
    end
    allB ? res : nothing
end
function query(mb::MessageBuffer, query::Tag)
    for (depth, (src, tag)) in pairs(mb.buffer)
        tag==query && return (;depth, src, tag)
    end
    return nothing
end

"""Find an empty unlocked slot in a given [`Register`](@ref).

```jldoctest
julia> reg = Register(3); initialize!(reg[1], X); lock(reg[2]);

julia> findfreeslot(reg) == reg[3]
true

julia> lock(findfreeslot(reg));

julia> findfreeslot(reg) |> isnothing
true
```
"""
function findfreeslot(reg::Register; filter=minimum::Union{Int,<:Function}, randomize=false, margin=0)
    n_slots = length(reg.staterefs)
    n_freeslots = sum((!isassigned(reg[i]) for i in 1:n_slots))
    if n_freeslots < margin
        return nothing
    end
    freeslots = [i for i in 1:n_slots if !islocked(reg[i]) && !isassigned(reg[i])]
    if isempty(freeslots)
        return nothing
    end
    if filter isa Int
        return filter in freeslots ? reg[filter] : nothing
    else
        filtered_slots = filter(freeslots)
        if filtered_slots === nothing || isempty(filtered_slots)
            return nothing
        end
        if isa(filtered_slots, Integer)
            filtered_slots = [filtered_slots]
        end
        if randomize
            return reg[rand(filtered_slots)]
        else
            return reg[filtered_slots[1]]
        end
    end
end

struct NotAssignedError <: Exception # TODO use this in all places where we are throwing something on isassigned (maybe rename to IsAssignedError and check whether we need to keep `f` as part of it (might already be provided by the stacktrace) and check it does not allocate even when the error is not triggered)
    msg
    f
end

function Base.showerror(io::IO, err::NotAssignedError)
    print(io, "NotAssignedError: ")
    println(io, err.msg)
    println("In function: $(err.f)")
end

function isolderthan(slot::RegRef, age::Float64)
    if !isassigned(slot) throw(NotAssignedError("Slot must be assigned with a quantum state before checking coherence.", isolderthan)) end
    id = query(slot, QuantumSavory.ProtocolZoo.EntanglementCounterpart, ❓, ❓).id
    slot_time  = slot.reg.tag_info[id][3]
    return (now(get_time_tracker(slot))) - slot_time > age
end


function Base.isassigned(r::Register,i::Int) # TODO erase
    r.stateindices[i] != 0 # TODO this also usually means r.staterefs[i] !== nothing - choose one and make things consistent
end
Base.isassigned(r::RegRef) = isassigned(r.reg, r.idx)