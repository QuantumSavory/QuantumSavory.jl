struct MessageBuffer{T}
    sim::Simulation
    net # TODO ::RegisterNet -- this can not be typed due to circular dependency, see https://github.com/JuliaLang/julia/issues/269
    node::Int
    buffer::Vector{NamedTuple{(:src,:tag), Tuple{Int,T}}}
    waiters::IdDict{Resource,Resource}
    no_wait::Ref{Int} # keeps track of the situation when something is pushed in the buffer and no waiters are present. In that case, when the waiters are available after it they would get locked while the code that was supposed to unlock them has already run. So, we keep track the number of times this happens and put no lock on the waiters in this situation.
end

struct ChannelForwarder
    net # TODO type it as ::RegisterNet
    src::Int
    dst::Int
end

function Base.put!(cf::ChannelForwarder, tag::Tag)
    # shortest path calculated by Graphs.a_star
    nexthop = first(a_star(cf.net.graph, cf.src, cf.dst))
    @debug "ChannelForwarder: Forwarding message from node $(nexthop.src) to node $(nexthop.dst) | message=$(tag)| end destination=$(cf.dst)"
    put!(channel(cf.net, cf.src=>nexthop.dst; permit_forward=false), tag_types.Forward(tag, cf.dst))
end

@resumable function take_loop_mb(sim, ch, src, mb)
    while true
        tag = @yield take!(ch)
        @cases tag begin
            Forward(innertag, enddestination) => begin # inefficient -- it recalculates the a_star at each hop TODO provide some caching mechanism
                @debug "MessageBuffer @$(mb.node) at t=$(now(mb.sim)): Forwarding message to node $(enddestination) | message=`$(tag)`"
                put!(channel(mb.net, mb.node=>enddestination; permit_forward=true), innertag)
            end
            _ => begin
                #println("from $src storing in mb: $tag at $(now(sim))")
                @debug "MessageBuffer @$(mb.node) at t=$(now(mb.sim)): Receiving from source $(src) | message=`$(tag)`"
                length(mb.waiters) == 0 && @debug "MessageBuffer @$(mb.node) received a message, but there is no one waiting on that message buffer. The message was `$(tag)`."
                if length(mb.waiters) == 0
                    mb.no_wait[] += 1
                end
                push!(mb.buffer, (;src,tag));
                for waiter in keys(mb.waiters)
                    unlock(waiter)
                end
            end
        end
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
    @process wait_process(mb.sim, mb)
end
