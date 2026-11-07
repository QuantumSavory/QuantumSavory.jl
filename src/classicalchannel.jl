# A classical channel handle owns its arrival notifications; callers obtain it
# through `channel` rather than depending on the transport implementation.
struct ClassicalChannel{T}
    queue::DelayQueue{T}
    arrival::ChangeNotifier
end

ClassicalChannel(queue::DelayQueue{T}) where {T} = ClassicalChannel(queue, ChangeNotifier(queue.store.env))
ClassicalChannel{T}(env::Environment, delay) where {T} = ClassicalChannel(DelayQueue{T}(env, delay))

_notify_channel_arrival(event, arrival) = unlock(arrival)

function _put_with_notification(queue, value, arrival)
    event = put!(queue, value)
    ConcurrentSim.@callback _notify_channel_arrival(event, arrival)
    return event
end

"""
    put!(ch::ClassicalChannel, message)

Send a classical message through a direct [`channel`](@ref). Return the
transmission process, which completes after the channel delay.
"""
Base.put!(ch::ClassicalChannel, message) = _put_with_notification(ch.queue, message, ch.arrival)

"""
    take!(ch::ClassicalChannel)

Return a yieldable event that receives the next classical message.

!!! warning
    A network's [`messagebuffer`](@ref) already receives from its incoming
    channels. Taking directly from a network channel competes with that buffer.
    Use [`querydelete_wait!`](@ref) on the message buffer to receive messages.
"""
Base.take!(ch::ClassicalChannel) = take!(ch.queue)

"""
    isready(ch::ClassicalChannel)

Return whether an arrived classical message is available now. Messages still
in transit do not count. This check does not consume or reserve a message.

!!! warning
    A network's [`messagebuffer`](@ref) already receives from its incoming
    channels, so the channel can be empty after a message arrives. Use
    [`query`](@ref) on the message buffer to inspect received messages.
"""
Base.isready(ch::ClassicalChannel) = isready(ch.queue.store)

channel_delay(ch::ClassicalChannel) = ch.queue.delay

"""
    onchange(ch::ClassicalChannel)

Return a yieldable notification for the next classical arrival. The wait is
registered before this call returns. An arrival wakes all registered waiters;
waking does not consume or reserve a message. Check readiness before waiting
and again after waking.

!!! warning
    A network's [`messagebuffer`](@ref) already receives from its incoming
    channels. Use `onchange(messagebuffer(net, node))` or [`query_wait`](@ref)
    to wait for messages in that buffer.
"""
onchange(ch::ClassicalChannel) = lock(ch.arrival)
