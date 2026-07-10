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

   if cf.src == cf.dst 
    put!(messagebuffer(cf.net, cf.dst), tag)
    return nothing 
   end

   path = Graphs.a_star(cf.net.graph, cf.src, cf.dst)
   @assert !isempty(path) "No route from node $(cf.src) to destination $(cf.dst)"

   edge = first(path)
   nexthop = edge.src == cf.src ? edge.dst : edge.src

   @debug "ChannelForwarder: Forwarding message from node $(cf.src) to node $(nexthop) | message = $(tag) | end destination=$(cf.dst)"

   put!(
    channel(cf.net, cf.src => nexthop; permit_forward=false),
    tag_types.Forward(tag, cf.dst)
   )
   return nothing
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
        _tag = @yield take!(ch)
        tag = _tag::Tag

        @cases tag begin
            Forward(innertag, enddestination) => begin
                @debug "MessageBuffer @$(mb.node) at t=$(now(mb.sim)): Forwarding message to node $(enddestination) | message`$(tag)`"
                
                if mb.node == enddestination
                    put_and_unlock_waiters(mb, src, innertag)
                else
                    put!(channel(mb.net, mb.node=>enddestination; permit_forward=true), innertag)
                end
            end
            _ => begin
                put_and_unlock_waiters(mb, src, tag)
            end
        end
    end
end

function put_and_unlock_waiters(mb::MessageBuffer, src, tag)
    @debug "MessageBuffer @$(mb.node) at t=$(now(mb.sim)): Receiving from source $(src) | message=`$(tag)`"
    nwaiters = nbwaiters(mb.tag_waiter)
    nwaiters == 0 && @debug "MessageBuffer @$(mb.node) received a message from $(src), but there is no one waiting on that message buffer. The message was `$(tag)`."
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
