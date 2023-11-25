struct MessageBuffer{T}
    queue::DelayQueue{T}
    buffer::Vector{T}
end

@resumable function take_loop_mb(env, q, mb)
    while true
        msg = @yield take!(q)
        push!(mb.buffer, msg)
    end
end

function MessageBuffer(q::DelayQueue{T}) where {T}
    mb = MessageBuffer{T}(q, T[])
    @process take_loop_mb(q.store.env, q, mb)
    mb
end
