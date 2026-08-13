"""
A a buffer for classical messages. Usually a part of a [`Register`](@ref) structure.

See also: [`channel`](@ref), [`messagebuffer`](@ref)
"""
struct MessageBuffer{T}
    sim::Simulation
    net # TODO ::RegisterNet -- this can not be typed due to circular dependency, see https://github.com/JuliaLang/julia/issues/269
    node::Int
    buffer::Vector{NamedTuple{(:src,:tag), Tuple{Union{Nothing, Int},T}}}
    buffer_ids::Vector{Int128}
    buffer_depth_by_id::Dict{Int128, Int}
    buffer_ids_by_head::Dict{TagElementTypes, Vector{Int128}}
    # `tag_waiter` is edge-triggered: it wakes tasks that are already blocked in
    # `wait`/`onchange`.
    tag_waiter::ChangeNotifier
    # `no_wait` counts arrivals that happened while nobody was waiting. This
    # preserves the long-standing MessageBuffer contract that a later
    # `wait`/`onchange` must wake immediately once per already-buffered arrival.
    no_wait::Ref{Int}
end

function peektags(mb::MessageBuffer)
    [b.tag for b in mb.buffer]
end

function _index_messagebuffer_id!(mb::MessageBuffer, id::Int128, tag::Tag)
    head = _tag_index_head(tag)
    isnothing(head) || push!(get!(Vector{Int128}, mb.buffer_ids_by_head, head), id)
    return nothing
end

function _unindex_messagebuffer_id!(mb::MessageBuffer, id::Int128, tag::Tag)
    head = _tag_index_head(tag)
    if !isnothing(head)
        ids = get(mb.buffer_ids_by_head, head, nothing)
        if !isnothing(ids)
            i = findfirst(==(id), ids)
            isnothing(i) || deleteat!(ids, i)
            isempty(ids) && delete!(mb.buffer_ids_by_head, head)
        end
    end
    return nothing
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
    @debug(
        "Forwarded a network message",
        _group=LOG_GROUPS.network,
        event=:message_forwarded,
        simulation_log_context(get_time_tracker(cf.net))...,
        component=:ChannelForwarder,
        src_node=nexthop.src,
        dst_node=nexthop.dst,
        message_type=_message_type(tag),
    )
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
                @debug(
                    "Forwarded a network message",
                    _group=LOG_GROUPS.network,
                    event=:message_forwarded,
                    simulation_log_context(mb.sim)...,
                    component=:MessageBuffer,
                    src_node=mb.node,
                    dst_node=enddestination,
                    message_type=_message_type(innertag),
                )
                put!(channel(mb.net, mb.node=>enddestination; permit_forward=true), innertag)
            end
            _ => begin
                put_and_unlock_waiters(mb, src, tag)
            end
        end
    end
end

function put_and_unlock_waiters(mb::MessageBuffer, src, tag)
    @debug(
        "Received a network message",
        _group=LOG_GROUPS.network,
        event=:message_received,
        simulation_log_context(mb.sim)...,
        component=:MessageBuffer,
        src_node=src,
        dst_node=mb.node,
        message_type=_message_type(tag),
    )
    nwaiters = nbwaiters(mb.tag_waiter)
    nwaiters == 0 && @debug(
        "A network message arrived without a waiter",
        _group=LOG_GROUPS.network,
        event=:message_arrived_without_waiter,
        simulation_log_context(mb.sim)...,
        component=:MessageBuffer,
        src_node=src,
        dst_node=mb.node,
        message_type=_message_type(tag),
    )
    id = guid()
    push!(mb.buffer, (;src,tag));
    push!(mb.buffer_ids, id)
    mb.buffer_depth_by_id[id] = length(mb.buffer)
    _index_messagebuffer_id!(mb, id, tag)
    if nwaiters == 0
        # Keep one queued wakeup per arrival when no task is actively blocked on
        # the notifier. Protocol code often queries the buffer first and only
        # then calls `onchange`, so a pure edge-triggered notifier would miss
        # already-buffered work and can deadlock those protocols.
        mb.no_wait[] += 1
    else
        unlock(mb.tag_waiter)
    end
end

function MessageBuffer(net, node::Int, qs::Vector{NamedTuple{(:src,:channel), Tuple{Int, DelayQueue{T}}}}) where {T}
    sim = get_time_tracker(net)
    mb = MessageBuffer{T}(
        sim, net, node,
        NamedTuple{(:src,:tag), Tuple{Union{Nothing, Int},T}}[],
        Int128[],
        Dict{Int128, Int}(),
        Dict{TagElementTypes, Vector{Int128}}(),
        ChangeNotifier(sim),
        Ref(0)
    )
    for (;src, channel) in qs
        @process take_loop_mb(sim, channel, src, mb)
    end
    mb
end

@resumable function wait_process(sim, mb)
    if mb.no_wait[] != 0
        # Consume a queued arrival immediately instead of waiting for a future
        # edge on `tag_waiter`.
        mb.no_wait[] -= 1
        return
    end
    @yield lock(mb.tag_waiter)
end

function Base.wait(mb::MessageBuffer)
    Base.depwarn("wait(::MessageBuffer) is deprecated, use onchange(::MessageBuffer) instead", :wait)
    return @process wait_process(mb.sim, mb)
end

"""
Wait for changes to occur on a [`MessageBuffer`](@ref) or [`Register`](@ref). By specifying a second argument, you can filter what type of events are waited on.
E.g. `onchange(r, Tag)` will wait only on changes to tags and metadata.
"""
function onchange end

function onchange(mb::MessageBuffer)
    return @process wait_process(mb.sim, mb)
end

function onchange(mb::MessageBuffer, ::Type{Any})
    onchange(mb)
end

function onchange(mb::MessageBuffer, ::Type{Tag})
    # For now, this behaves the same as the basic version
    onchange(mb)
end
