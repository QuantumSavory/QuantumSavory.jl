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

mutable struct ChangeWait <: ConcurrentSim.AbstractEvent
    const bev::ConcurrentSim.BaseEvent
    const generation::Union{Nothing,ChangeGeneration}
    callback::Union{Nothing,Function}
end
ChangeWait(sim, generation=nothing) = ChangeWait(ConcurrentSim.BaseEvent(sim), generation, nothing)

ConcurrentSim.abandon_on_unobserved(::ChangeWait) = true
ConcurrentSim.on_abandon(wait::ChangeWait) = _release_change!(wait)

function _release_change!(wait::ChangeWait)
    callback = wait.callback
    isnothing(callback) && return nothing
    wait.callback = nothing
    generation = wait.generation::ChangeGeneration
    generation.waiters -= 1
    ConcurrentSim.remove_callback(callback, generation.event)
    return nothing
end

function _notify_change(event, wait::ChangeWait)
    wait.bev.abandoned && return nothing
    _release_change!(wait)
    ConcurrentSim.schedule(wait)
    return nothing
end

function Base.lock(n::ChangeNotifier)
    generation = n.current
    wait = ChangeWait(ConcurrentSim.environment(generation.event), generation)
    wait.callback = ConcurrentSim.append_callback(_notify_change, generation.event, wait)
    generation.waiters += 1
    return wait
end

function unlock(n::ChangeNotifier)
    generation = n.current
    generation.waiters == 0 && return nothing

    n.current = ChangeGeneration(ConcurrentSim.environment(generation.event))
    ConcurrentSim.succeed(generation.event)
    return nothing
end

nbwaiters(n::ChangeNotifier) = n.current.waiters
