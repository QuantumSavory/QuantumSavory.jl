struct MessageBuffer{T}
    sim::Simulation
    net # TODO ::RegisterNet -- this can not be typed due to circular dependency, see https://github.com/JuliaLang/julia/issues/269
    node::Int
    buffer::Vector{NamedTuple{(:src,:tag), Tuple{Int,T}}}
    waiters::IdDict{Resource,Resource}
end

struct ChannelForwarder
    net # TODO type it as ::RegisterNet
    src::Int
    dst::Int
end

function Base.put!(cf::ChannelForwarder, tag::Tag)
    # shortest path calculated by Graphs.a_star
    nexthop = first(a_star(cf.net.graph, cf.src, cf.dst))
    put!(channel(cf.net, cf.src=>nexthop.dst; permit_forward=false), tag_types.Forward(tag, cf.dst))
end

@resumable function take_loop_mb(sim, ch, src, mb)
    while true
        tag = @yield take!(ch)
        @cases tag begin
            Forward(innertag, enddestination) => begin # inefficient -- it recalculates the a_star at each hop TODO provide some caching mechanism
                put!(channel(mb.net, mb.node=>enddestination; permit_forward=true), innertag)
            end
            _ => begin
                #println("from $src storing in mb: $tag at $(now(sim))")
                push!(mb.buffer, (;src,tag));
                for waiter in keys(mb.waiters)
                    unlock(waiter)
                end
            end
        end
    end
end

function MessageBuffer(net, node::Int, qs::Vector{NamedTuple{(:src,:channel), Tuple{Int, DelayQueue{T}}}}) where {T}
    sim = qs[1].channel.store.env
    signal = IdDict{Resource,Resource}()
    mb = MessageBuffer{T}(sim, net, node, Tuple{Int,T}[], signal)
    for (;src, channel) in qs
        @process take_loop_mb(sim, channel, src, mb)
    end
    mb
end

@resumable function wait_process(sim, mb::MessageBuffer)
    waitresource = Resource(sim)
    lock(waitresource)
    mb.waiters[waitresource] = waitresource
    @yield lock(waitresource)
    pop!(mb.waiters, waitresource)
end

function Base.wait(mb::MessageBuffer)
    @process wait_process(mb.sim, mb)
end
