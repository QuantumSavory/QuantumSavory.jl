struct MessageBuffer{T}
    queue::DelayQueue{T}
    buffer::Vector{T}
    signalreception::Resource
end

@resumable function take_loop_mb(env, q, mb)
    while true
        @yield lock(mb.signalreception)
        msg = @yield take!(q)
        push!(mb.buffer, msg)
        unlock(mb.signalreception)
    end
end

function MessageBuffer(q::DelayQueue{T}) where {T}
    mb = MessageBuffer{T}(q, T[], ConcurrentSim.Resource(q.store.env))
    @process take_loop_mb(q.store.env, q, mb)
    mb
end

@resumable function wait_process(env, mb::MessageBuffer)
    @yield lock(mb.signalreception)
    unlock(mb.signalreception)
end

function Base.wait(mb::MessageBuffer)
    @process wait_process(mb.queue.store.env, mb)
end
