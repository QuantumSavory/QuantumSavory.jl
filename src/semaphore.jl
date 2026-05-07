"""Multiple processes can wait on this semaphore for a permission to run given by another process.

However, if a process is waiting on the semaphore and then immediately starts waiting on it again, it will cause an infinite loop,
because the semaphore will continue unlocking processes until all waiting processes are unlocked."""
mutable struct SimpleAsymmetricSemaphore # An equivalent, allocating, simpler implementation of this capability is in wait(::MessageBuffer)
    nbwaiters::Int
    unlocking::Bool
    parent::Any                       # back-pointer to the owning AsymmetricSemaphore (or nothing)
    const lock::Resource
end
SimpleAsymmetricSemaphore(sim) = SimpleAsymmetricSemaphore(0, false, nothing, Resource(sim,1,level=1)) # start locked

function Base.lock(s::SimpleAsymmetricSemaphore)
    s.nbwaiters += 1
    return @process _lock(s.lock.env, s)
end

@resumable function _lock(sim, s::SimpleAsymmetricSemaphore)
    @yield lock(s.lock)
    s.nbwaiters -= 1
    if s.nbwaiters > 0
        unlock(s.lock)
    else
        s.unlocking = false
        # Cascade ended. If the owning AsymmetricSemaphore had unlock signals
        # dropped while this side was cascading, fire one of them now so the
        # waiters that re-locked into the other sub-semaphore (and any new
        # waiters that arrived since) actually get woken.
        p = s.parent
        if p !== nothing
            _drain_pending_unlock(p::AsymmetricSemaphore)
        end
    end
end

function unlock(s::SimpleAsymmetricSemaphore)
    if s.nbwaiters > 0
        s.unlocking = true
        unlock(s.lock)
    end
    return nothing
end

function islocked(s::SimpleAsymmetricSemaphore)
    return islocked(s.lock)
end


"""Multiple processes can wait on this semaphore for a permission to run given by another process.

Internally, it is implemented as a pair of SimpleAsymmetricSemaphores -- whenever one of them is unlocked,
we switch to the other one, thus avoiding infinite loops when a process waits on the semaphore and then immediately starts waiting on it again.

Unlock calls that arrive while a cascade is in progress are queued in
`pending_unlocks` and replayed when the cascade ends, so wakeup signals are
never silently dropped.
"""
mutable struct AsymmetricSemaphore # An equivalent, allocating, simpler implementation of this capability is in wait(::MessageBuffer)
    current_semaphore::Int
    pending_unlocks::Int
    const semaphorepair::Tuple{SimpleAsymmetricSemaphore, SimpleAsymmetricSemaphore}
end
function AsymmetricSemaphore(sim)
    s1 = SimpleAsymmetricSemaphore(sim)
    s2 = SimpleAsymmetricSemaphore(sim)
    parent = AsymmetricSemaphore(1, 0, (s1, s2))
    s1.parent = parent
    s2.parent = parent
    return parent
end

function Base.lock(s::AsymmetricSemaphore)
    sem = s.semaphorepair[s.current_semaphore]
    lock(sem)
end

function unlock(s::AsymmetricSemaphore)
    if s.semaphorepair[1].unlocking || s.semaphorepair[2].unlocking
        # A cascade is in progress on at least one sub-semaphore. Triggering a
        # second cascade now would either be silently merged into the running
        # one (if it lands on the same sub-sem) or create concurrent cascades
        # that re-feed each other (if it lands on the other side, since the
        # newly toggled `current` would be the still-cascading one). Queue the
        # unlock instead and replay it from `_lock` when the running cascade
        # completes.
        s.pending_unlocks += 1
        return nothing
    end
    sem = s.semaphorepair[s.current_semaphore]
    s.current_semaphore = 3 - s.current_semaphore
    unlock(sem)
    return nothing
end

# Called by `_lock` when its sub-semaphore's cascade ends. Fires one queued
# unlock against the (now fresh) opposite sub-semaphore. Each queued unlock
# eventually surfaces because every cascade ends in `_lock`, which calls back
# into this drain.
function _drain_pending_unlock(s::AsymmetricSemaphore)
    if s.pending_unlocks > 0 && !(s.semaphorepair[1].unlocking || s.semaphorepair[2].unlocking)
        s.pending_unlocks -= 1
        sem = s.semaphorepair[s.current_semaphore]
        s.current_semaphore = 3 - s.current_semaphore
        unlock(sem)
    end
    return nothing
end

function islocked(s::AsymmetricSemaphore)
    sem = s.semaphorepair[s.current_semaphore]
    return islocked(sem)
end

function nbwaiters(s::AsymmetricSemaphore)
    #s1, s2 = s.semaphorepair
    #return s1.nbwaiters + s2.nbwaiters
    return s.semaphorepair[s.current_semaphore].nbwaiters
end
