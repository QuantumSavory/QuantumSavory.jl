using ResumableFunctions
import SimJulia # Should be using
using SimJulia: Environment, request, release, now, active_process
using Printf

export @simlog, isfree, nongreedymultilock, spinlock

macro simlog(env, msg) # this should be part of @process or @resumable and just convert @info and company
    return :(@info(@sprintf("t=%.4f @ %05d : %s", now($(esc(env))), active_process($(esc(env))).bev.id, $(esc(msg)))))
end

isfree(resource) = resource.level == 0

@resumable function nongreedymultilock(env::Environment, resources)
    while true
        if all(isfree(r) for r in resources)
            @yield mapreduce(request, &, resources)
            break
        else
            for r in resources
                if !isfree(r)
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
        if all(isfree, resources)
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
