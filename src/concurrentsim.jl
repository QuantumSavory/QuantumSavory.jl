export @simlog, nongreedymultilock, spinlock, get_time_tracker

macro simlog(env, msg) # this should be part of @process or @resumable and just convert @info and company
    return :(@info(@sprintf("t=%.4f @ %05d : %s", now($(esc(env))), active_process($(esc(env))).bev.id, $(esc(msg)))))
end

@resumable function nongreedymultilock(env::Environment, resources)
    while true
        if all(!islocked(r)::Bool for r in resources) # type assert to help with inference
            @yield mapreduce(request, &, resources)
            break
        else
            for r in resources
                if islocked(r)
                    @yield request(r)
                    release(r)
                    break
                end
            end
        end
    end
end

@resumable function spinlock(env::Environment, resources, period; randomize=true)
    while true
        if all(x->!islocked(x), resources)
            @yield mapreduce(request, &, resources)
            break
        else
            if randomize
                @yield timeout(env, rand()*period)
            else
                @yield timeout(env, period)
            end
        end
    end
end

##

function get_time_tracker(rn::RegisterNet)
    return get_time_tracker(rn.registers[1])
end
function get_time_tracker(r::Register)
    r.locks[1].env
end
function get_time_tracker(r::RegRef)
    get_time_tracker(r.reg)
end

##

Base.islocked(r::RegRef) = islocked(r.reg.locks[r.idx])
ConcurrentSim.request(r::RegRef) = request(r.reg.locks[r.idx])
Base.unlock(r::RegRef) = unlock(r.reg.locks[r.idx])

##

struct NetworkSimulation <: ConcurrentSim.Environment
    sim::Simulation
    glcnt::Ref{Int128}
end

function NetworkSimulation()
    return NetworkSimulation(Simulation(), Ref{Int128}(0))
end

function Base.show(io::IO, env::NetworkSimulation)
    if env.sim.active_proc === nothing
        print(io, "$(typeof(env)) time: $(now(env.sim)) active_process: nothing")
      else
        print(io, "$(typeof(env)) time: $(now(env.sim)) active_process: $(env.sim.active_proc)")
    end
end

function ConcurrentSim.now(env::NetworkSimulation)
    env.sim.time
end

function ConcurrentSim.put!(con::ConcurrentSim.Container{N, T}, amount::N; priority=zero(T)) where {N<:Real, T<:Number}
    put_ev = ConcurrentSim.Put(con.env.sim)
    con.put_queue[put_ev] = ConcurrentSim.ContainerKey{N,T}(con.seid+=one(UInt), amount, T(priority))
    ConcurrentSim.@callback ConcurrentSim.trigger_get(put_ev, con)
    ConcurrentSim.trigger_put(put_ev, con)
    put_ev
end

function ConcurrentSim.get(con::ConcurrentSim.Container{N, T}, amount::N; priority=zero(T)) where {N<:Real, T<:Number}
    get_ev = ConcurrentSim.Get(con.env.sim)
    con.get_queue[get_ev] = ConcurrentSim.ContainerKey(con.seid+=one(UInt), amount, T(priority))
    ConcurrentSim.@callback ConcurrentSim.trigger_put(get_ev, con)
    ConcurrentSim.trigger_get(get_ev, con)
    get_ev
end

function ConcurrentSim.timeout(env::Environment, delay::Number=0; priority=0, value::Any=nothing)
    ConcurrentSim.schedule(ConcurrentSim.Timeout(env.sim), delay; priority=Int(priority), value)
end

function ConcurrentSim.step(netsim::NetworkSimulation)
    isempty(netsim.sim.heap) && throw(ConcurrentSim.EmptySchedule())
    (bev, key) = DataStructures.peek(netsim.sim.heap)
    DataStructures.dequeue!(netsim.sim.heap)
    netsim.sim.time = key.time
    bev.state = ConcurrentSim.processed
    for callback in bev.callbacks
      callback()
    end
end