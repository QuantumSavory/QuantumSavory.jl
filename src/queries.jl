"""Assign a tag to a slot in a register.

See also: [`query`](@ref)"""
function tag!(ref::RegRef, tag::Tag)
    push!(ref.reg.tags[ref.idx], tag)
end

function untag!(ref::RegRef, tag::Tag) # TODO rather slow implementation. See issue #74
    tags = ref.reg.tags[ref.idx]
    i = findfirst(==(tag), tags)
    isnothing(i) ? throw(KeyError(tag)) : deleteat!(tags, i) # TODO make sure there is a clear error message
end

"""Wildcard for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref)"""
struct Wildcard end

"""A wildcard instance for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`Wildcard`](@ref)"""
const W = Wildcard()

"""A wildcard instance for use with the tag querying functionality.

See also: [`query`](@ref), [`tag!`](@ref), [`Wildcard`](@ref)"""
const ❓ = W

""" A query function that returns all slots of a register that have a given tag, with support for predicates and wildcards.

```jldoctest
julia> r = Register(10);
       tag!(r[1], :symbol, 2, 3);
       tag!(r[2], :symbol, 4, 5);

julia> queryall(r, :symbol, ❓, ❓)
2-element Vector{NamedTuple{(:slot, :tag), Tuple{RegRef, Tag}}}:
 (slot = Slot 1, tag = SymbolIntInt(:symbol, 2, 3)::Tag)
 (slot = Slot 2, tag = SymbolIntInt(:symbol, 4, 5)::Tag)

julia> queryall(r, :symbol, ❓, >(4))
1-element Vector{NamedTuple{(:slot, :tag), Tuple{RegRef, Tag}}}:
 (slot = Slot 2, tag = SymbolIntInt(:symbol, 4, 5)::Tag)

julia> queryall(r, :symbol, ❓, >(5))
NamedTuple{(:slot, :tag), Tuple{RegRef, Tag}}[]
```
"""
queryall(args...; kwargs...) = query(args..., Val{true}(); kwargs...)


""" A query function searching for the first slot in a register that has a given tag.

Wildcards are supported (instances of `Wildcard` also available as the constants [`W`](@ref) or the emoji [`❓`](@ref) which can be entered as `\\:question:` in the REPL).
Predicate functions are also supported (they have to be `Int`↦`Bool` functions).
The keyword arguments `locked` and `assigned` can be used to check, respectively,
whether the given slot is locked or whether it contains a quantum state.

```jldoctest
julia> r = Register(10);
       tag!(r[1], :symbol, 2, 3);
       tag!(r[2], :symbol, 4, 5);


julia> query(r, :symbol, 4, 5)
(slot = Slot 2, tag = SymbolIntInt(:symbol, 4, 5)::Tag)

julia> lock(r[1]);

julia> query(r, :symbol, 4, 5; locked=false) |> isnothing
false

julia> query(r, :symbol, ❓, 3)
(slot = Slot 1, tag = SymbolIntInt(:symbol, 2, 3)::Tag)

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
(slot = Slot 5, tag = TypeIntInt(Int64, 4, 5)::Tag)
```

See also: [`queryall`](@ref), [`tag!`](@ref), [`Wildcard`](@ref)
"""
function query(reg::Register, tag::Tag, ::Val{allB}=Val{false}(); locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing) where {allB}
    find = allB ? findall : findfirst
    i = find(i -> _nothingor(locked, islocked(reg[i])) && _nothingor(assigned, isassigned(reg[i])) && tag ∈ reg.tags[i],
                  1:length(reg))
    if allB
        return NamedTuple{(:slot, :tag), Tuple{RegRef, Tag}}[(slot=reg[i], tag=tag) for i in i]
    else
        isnothing(i) ? nothing : (;slot=reg[i], tag=tag)
    end
end

"""A [`query`](@ref) for classical message buffers.

You are advised actually use [`querypop!`](@ref), not `query` when working with classical message buffers."""
function query(mb::MessageBuffer, tag::Tag)
    i = findfirst(==(tag), mb.buffer)
    return isnothing(i) ? nothing : (;slot=i, tag=mb.buffer[i])
end

raw"""A [`query`](@ref) for classical message buffers that also pops the message out of the buffer.

```jldoctest
julia> net = RegisterNet([Register(3), Register(2)])
A network of 2 registers in a graph of 1 edges


julia> put!(channel(net, 1=>2), Tag(:my_tag))
ConcurrentSim.Process 5

julia> net = RegisterNet([Register(3), Register(2)])
A network of 2 registers in a graph of 1 edges

julia> put!(channel(net, 1=>2), Tag(:my_tag));

julia> put!(channel(net, 1=>2), Tag(:another_tag, 123, 456));

julia> query(messagebuffer(net, 1=>2), :my_tag)

julia> run(get_time_tracker(net))

julia> query(messagebuffer(net, 1=>2), :my_tag)
(slot = 1, tag = Symbol(:my_tag)::Tag)

julia> querypop!(messagebuffer(net, 1=>2), :my_tag)
Symbol(:my_tag)::Tag

julia> querypop!(messagebuffer(net, 1=>2), :my_tag) === nothing
true

julia> querypop!(messagebuffer(net, 1=>2), :another_tag, ❓, ❓)
SymbolIntInt(:another_tag, 123, 456)::Tag

julia> querypop!(messagebuffer(net, 1=>2), :another_tag, ❓, ❓) === nothing
true
```

You can also wait on a message buffer for a message to arrive before runnign a query:

```jldoctes
julia> net = RegisterNet([Register(3), Register(2)])
A network of 2 registers in a graph of 1 edges


julia> env = get_time_tracker(net);

julia> @resumable function receive_tags(env)
           while true
               mb = messagebuffer(net, 1=>2)
               @yield wait(mb)
               msg = querypop!(mb, :second_tag, ❓, ❓)
               println("t=$(now(env)): query returns $msg")
           end
       end
receive_tags (generic function with 1 method)

julia> @resumable function send_tags(env)
           @yield timeout(env, 1)
           put!(channel(net, 1=>2), Tag(:my_tag))
           @yield timeout(env, 2)
           put!(channel(net, 1=>2), Tag(:second_tag, 123, 456))
       end
send_tags (generic function with 1 method)

julia> @process send_tags(env);

julia> @process receive_tags(env);

julia> run(env, 10)
t=1.0: query returns nothing
t=3.0: query returns SymbolIntInt(:second_tag, 123, 456)::Tag
```
"""
function querypop!(mb::MessageBuffer, args...)
    r = query(mb, args...)
    return isnothing(r) ? nothing : popat!(mb.buffer, r.slot)
end

_nothingor(l,r) = isnothing(l) || l==r
_all() = true
_all(a::Bool) = a
_all(a::Bool, b::Bool) = a && b
_all(a::Bool, b::Bool, c::Bool) = a && b && c
_all(a::Bool, b::Bool, c::Bool, d::Bool) = a && b && c && d

# Create a query function for each combination of tag arguments and/or wildcard arguments
for (tagsymbol, tagvariant) in pairs(tag_types)
    sig = methods(tagvariant)[1].sig.parameters[2:end]
    args = (:a, :b, :c, :d)[1:length(sig)]
    argssig = [:($a::$t) for (a,t) in zip(args, sig)]

    eval(quote function tag!(ref::RegRef, $(argssig...))
        tag!(ref, ($tagvariant)($(args...)))
    end end)

    eval(quote function Tag($(argssig...))
        ($tagvariant)($(args...))
    end end)

    eval(quote function query(tagcontainer, $(argssig...), ars...; kwa...)
        query(tagcontainer, ($tagvariant)($(args...)), ars...; kwa...)
    end end)

    int_idx_all = [i for (i,s) in enumerate(sig) if s == Int]
    int_idx_combs = powerset(int_idx_all, 1)
    for idx in int_idx_combs
        complement_idx = tuple(setdiff(1:length(sig), idx)...)
        sig_wild = collect(sig)
        sig_wild[idx] .= Union{Wildcard,Function}
        argssig_wild = [:($a::$t) for (a,t) in zip(args, sig_wild)]
        wild_checks = [:(isa($(args[i]),Wildcard) || $(args[i])(tag.data[$i])) for i in idx]
        nonwild_checks = [:(tag.data[$i]==$(args[i])) for i in complement_idx]
        newmethod_reg = quote function query(reg::Register, $(argssig_wild...), ::Val{allB}=Val{false}(); locked::Union{Nothing,Bool}=nothing, assigned::Union{Nothing,Bool}=nothing) where {allB}
            res = NamedTuple{(:slot, :tag), Tuple{RegRef, Tag}}[]
            for (reg_idx, tags) in enumerate(reg.tags)
                slot = reg[reg_idx]
                for tag in tags
                    if isvariant(tag, ($(tagsymbol,))[1]) # a weird workaround for interpolating a symbol as a symbol
                        (_nothingor(locked, islocked(slot)) && _nothingor(assigned, isassigned(slot))) || continue
                        if _all($(nonwild_checks...)) && _all($(wild_checks...))
                            allB ? push!(res, (;slot, tag)) : return (;slot, tag)
                        end
                    end
                end
            end
            allB ? res : nothing
        end end
        newmethod_mb = quote function query(mb::MessageBuffer, $(argssig_wild...))
            for (slot, tag) in enumerate(mb.buffer)
                if isvariant(tag, ($(tagsymbol,))[1]) # a weird workaround for interpolating a symbol as a symbol
                    if _all($(nonwild_checks...)) && _all($(wild_checks...))
                        return (;slot, tag)
                    end
                end
            end
        end end
        #println(sig)
        #println(sig_wild)
        #println(newmethod_reg)
        eval(newmethod_reg)
        eval(newmethod_mb) # TODO there is a lot of code duplication here
    end
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
function findfreeslot(reg::Register)
    for slot in reg
        islocked(slot) || isassigned(slot) || return slot
    end
end

function Base.isassigned(r::Register,i::Int) # TODO erase
    r.stateindices[i] != 0 # TODO this also usually means r.staterenfs[i] !== nothing - choose one and make things consistent
end
Base.isassigned(r::RegRef) = isassigned(r.reg, r.idx)
