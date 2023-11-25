struct MessageBuffer{T}
    env::Simulation
    buffer::Vector{NamedTuple{(:src,:tag), Tuple{Int,T}}}
    waiters::IdDict{Resource,Resource}
end

@resumable function take_loop_mb(env, channel, src, mb)
    while true
        tag = @yield take!(channel)
        push!(mb.buffer, (;src,tag))
        for waiter in keys(mb.waiters)
            unlock(waiter)
        end
    end
end

function MessageBuffer(qs::Vector{NamedTuple{(:src,:channel), Tuple{Int, DelayQueue{T}}}}) where {T}
    env = qs[1].channel.store.env
    signal = IdDict{Resource,Resource}()
    mb = MessageBuffer{T}(env, Tuple{Int,T}[], signal)
    for (;src, channel) in qs
        @process take_loop_mb(env, channel, src, mb)
    end
    mb
end

@resumable function wait_process(env, mb::MessageBuffer)
    waitresource = Resource(env)
    lock(waitresource)
    mb.waiters[waitresource] = waitresource
    @yield lock(waitresource)
    pop!(mb.waiters, waitresource)
end

function Base.wait(mb::MessageBuffer)
    @process wait_process(mb.env, mb)
end
