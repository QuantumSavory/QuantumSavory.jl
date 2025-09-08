"""
A a buffer for classical messages. Usually a part of a [`Register`](@ref) structure.

See also: [`channel`](@ref), [`messagebuffer`](@ref)
"""
struct MessageBuffer{T}
    sim::Simulation
    net # TODO ::RegisterNet -- this can not be typed due to circular dependency, see https://github.com/JuliaLang/julia/issues/269
    node::Int
    buffer::Vector{NamedTuple{(:src,:tag), Tuple{Union{Nothing, Int},T}}}
    tag_waiter::AsymmetricSemaphore
end

function peektags(mb::MessageBuffer)
    [b.tag for b in mb.buffer]
end

struct ChannelForwarder
    net # TODO type it as ::RegisterNet
    src::Int
    dst::Int
end

function Base.put!(cf::ChannelForwarder, tag)
    tag = convert(Tag, tag)
    # shortest path calculated by Graphs.a_star
    nexthop = first(Graphs.a_star(cf.net.graph, cf.src, cf.dst))
    @debug "ChannelForwarder: Forwarding message from node $(nexthop.src) to node $(nexthop.dst) | message=$(tag)| end destination=$(cf.dst)"
    put!(channel(cf.net, cf.src=>nexthop.dst; permit_forward=false), tag_types.Forward(tag, cf.dst))
end

function Base.put!(mb::MessageBuffer, tag)
    put_and_unlock_waiters(mb, nothing, convert(Tag,tag))
    nothing
end
Base.put!(mb::MessageBuffer, args...) = put!(mb, Tag(args...))

tag!(::MessageBuffer, args...) = throw(ArgumentError("MessageBuffer does not support `tag!`. Use `put!(::MessageBuffer, Tag(...))` instead."))

function Base.put!(reg::Register, tag)
    put!(messagebuffer(reg), tag)
end

tag!(::Register, args...) = throw(ArgumentError("Register does not support `tag!`, only its slots do. But you can `put!` a `Tag` in its `messagebuffer(::Register)`."))

"""
This function is used to take messages from a channel and put them in a message buffer.
Importantly, it also unlocks all processes waiting on the message buffer.
"""
@resumable function take_loop_mb(sim, ch, src, mb)
    while true
        _tag = @yield take!(ch) # TODO: The type assert is necessary due to a bug in ResumableFunctions. The bug was probably introduced in https://github.com/JuliaDynamics/ResumableFunctions.jl/pull/76 which introduces type inference for resumable functions in julia >=1.10. The type assert is not necessary on julia 1.9.
        tag = _tag::Tag
        @cases tag begin
            Forward(innertag, enddestination) => begin # inefficient -- it recalculates the a_star at each hop TODO provide some caching mechanism
                @debug "MessageBuffer @$(mb.node) at t=$(now(mb.sim)): Forwarding message to node $(enddestination) | message=`$(tag)`"
                put!(channel(mb.net, mb.node=>enddestination; permit_forward=true), innertag)
            end
            _ => begin
                put_and_unlock_waiters(mb, src, tag)
            end
        end
    end
end

function put_and_unlock_waiters(mb::MessageBuffer, src, tag)
    @debug "MessageBuffer @$(mb.node) at t=$(now(mb.sim)): Receiving from source $(src) | message=`$(tag)`"
    islocked(mb.tag_waiter) || @debug "MessageBuffer @$(mb.node) received a message from $(src), but there is no one waiting on that message buffer. The message was `$(tag)`."
    push!(mb.buffer, (;src,tag));
    unlock(mb.tag_waiter)
end

function MessageBuffer(net, node::Int, qs::Vector{NamedTuple{(:src,:channel), Tuple{Int, DelayQueue{T}}}}) where {T}
    sim = get_time_tracker(net)
    mb = MessageBuffer{T}(sim, net, node, Tuple{Int,T}[], AsymmetricSemaphore(sim))
    for (;src, channel) in qs
        @process take_loop_mb(sim, channel, src, mb)
    end
    mb
end

function Base.wait(mb::MessageBuffer)
    Base.depwarn("wait(::MessageBuffer) is deprecated, use onchange(::MessageBuffer) instead", :wait)
    return lock(mb.tag_waiter)
end

"""
Wait for changes to occur on a [`MessageBuffer`](@ref) or [`Register`](@ref). By specifying a second argument, you can filter what type of events are waited on.
E.g. `onchange(r, Tag)` will wait only on changes to tags and metadata.
"""
function onchange end

function onchange(mb::MessageBuffer)
    return lock(mb.tag_waiter)
end

function onchange(mb::MessageBuffer, ::Type{Tag})
    # For now, this behaves the same as the basic version
    onchange(mb)
end
