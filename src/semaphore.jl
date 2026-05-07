"""Private edge-triggered change notification for `onchange`.

Each call to `lock` attaches to the current generation. `unlock` rotates to a
fresh generation before succeeding the old event, so tasks that wake and
immediately wait again are waiting for the next change, not for the same
notification cascade.
"""
mutable struct ChangeGeneration
    const event::ConcurrentSim.Event
    waiters::Int
end
ChangeGeneration(sim) = ChangeGeneration(ConcurrentSim.Event(sim), 0)

mutable struct ChangeNotifier
    current::ChangeGeneration
end
ChangeNotifier(sim::ConcurrentSim.Environment) = ChangeNotifier(ChangeGeneration(sim))

function Base.lock(n::ChangeNotifier)
    generation = n.current
    generation.waiters += 1
    return @process _wait_change(ConcurrentSim.environment(generation.event), generation)
end

@resumable function _wait_change(sim, generation::ChangeGeneration)
    @yield generation.event
end

function unlock(n::ChangeNotifier)
    generation = n.current
    generation.waiters == 0 && return nothing

    n.current = ChangeGeneration(ConcurrentSim.environment(generation.event))
    ConcurrentSim.succeed(generation.event)
    return nothing
end

nbwaiters(n::ChangeNotifier) = n.current.waiters
