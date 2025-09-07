struct MessageBuffer{T}
    sim::Simulation
    net # TODO ::RegisterNet -- this can not be typed due to circular dependency, see https://github.com/JuliaLang/julia/issues/269
    node::Int
    buffer::Vector{NamedTuple{(:src,:tag), Tuple{Union{Nothing, Int},T}}}
    waiters::IdDict{Resource,Resource}
    no_wait::Ref{Int} # keeps track of the situation when something is pushed in the buffer and no waiters are present. In that case, when the waiters are available after it they would get locked while the code that was supposed to unlock them has already run. So, we keep track the number of times this happens and put no lock on the waiters in this situation.
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
    length(mb.waiters) == 0 && @debug "MessageBuffer @$(mb.node) received a message from $(src), but there is no one waiting on that message buffer. The message was `$(tag)`."
    if length(mb.waiters) == 0
        mb.no_wait[] += 1
    end
    push!(mb.buffer, (;src,tag));
    for waiter in keys(mb.waiters)
        unlock(waiter)
    end
end

function MessageBuffer(net, node::Int, qs::Vector{NamedTuple{(:src,:channel), Tuple{Int, DelayQueue{T}}}}) where {T}
    sim = get_time_tracker(net)
    signal = IdDict{Resource,Resource}()
    no_wait = Ref{Int}(0)
    mb = MessageBuffer{T}(sim, net, node, Tuple{Int,T}[], signal, no_wait)
    for (;src, channel) in qs
        @process take_loop_mb(sim, channel, src, mb)
    end
    mb
end

@resumable function wait_process(sim, mb)
    if mb.no_wait[] != 0 # This happens only in the specific case when something is put in the buffer before there any waiters.
        mb.no_wait[] -= 1
        return
    end
    waitresource = Resource(sim)
    lock(waitresource)
    mb.waiters[waitresource] = waitresource
    @yield lock(waitresource)
    pop!(mb.waiters, waitresource)
end

function Base.wait(mb::MessageBuffer)
    Base.depwarn("wait(::MessageBuffer) is deprecated, use onchange(::MessageBuffer) instead", :wait)
    @process wait_process(mb.sim, mb)
end

"""
Wait for changes to occur on a [`MessageBuffer`](@ref) or [`Register`](@ref). By specifying a second argument, you can filter what type of events are waited on.
E.g. `onchange(r, Tag)` will wait only on changes to tags and metadata.
"""
function onchange end

function onchange(mb::MessageBuffer)
    @process wait_process(mb.sim, mb)
end

function onchange(mb::MessageBuffer, ::Type{Tag})
    # For now, this behaves the same as the basic version
    onchange(mb)
end
