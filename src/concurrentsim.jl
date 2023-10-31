using ResumableFunctions
import ConcurrentSim # Should be using
using ConcurrentSim: Environment, request, release, now, active_process, timeout, Store, @process, Process, put, get
using Printf

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
    r.env
end
function get_time_tracker(r::RegRef)
    get_time_tracker(r.reg)
end

##

Base.islocked(r::RegRef) = islocked(r.reg.locks[r.idx])
ConcurrentSim.request(r::RegRef) = request(r.reg.locks[r.idx])
Base.unlock(r::RegRef) = unlock(r.reg.locks[r.idx])
