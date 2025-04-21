"""Multiple processes can wait on this semaphore for a permission to run given by another process.

However, if a process is waiting on the semaphore and then immediately starts waiting on it again, it will cause an infinite loop,
because the semaphore will continue unlocking processes until all waiting processes are unlocked."""
mutable struct SimpleAsymmetricSemaphore # An equivalent, allocating, simpler implementation of this capability is in wait(::MessageBuffer)
    nbwaiters::Int
    unlocking::Bool
    const lock::Resource
end
SimpleAsymmetricSemaphore(sim) = SimpleAsymmetricSemaphore(0, false, Resource(sim,1,level=1)) # start locked

function Base.lock(s::SimpleAsymmetricSemaphore)
    return @process _lock(s.lock.env, s)
end

@resumable function _lock(sim, s::SimpleAsymmetricSemaphore)
    s.nbwaiters += 1
    @yield lock(s.lock)
    s.nbwaiters -= 1
    if s.nbwaiters > 0
        unlock(s.lock)
    else
        s.unlocking = false
    end
end

function unlock(s::SimpleAsymmetricSemaphore)
    if s.nbwaiters[] > 0
        s.unlocking = true
        unlock(s.lock)
    end
end

function islocked(s::SimpleAsymmetricSemaphore)
    return islocked(s.lock)
end


"""Multiple processes can wait on this semaphore for a permission to run given by another process.

Internally, it is implemented as a pair of SimpleAsymmetricSemaphores -- whenever one of them is unlocked,
we switch to the other one, thus avoiding infinite loops when a process waits on the semaphore and then immediately starts waiting on it again.
"""
mutable struct AsymmetricSemaphore # An equivalent, allocating, simpler implementation of this capability is in wait(::MessageBuffer)
    current_semaphore::Int
    const semaphorepair::Tuple{SimpleAsymmetricSemaphore, SimpleAsymmetricSemaphore}
end
AsymmetricSemaphore(sim) = AsymmetricSemaphore(1, (SimpleAsymmetricSemaphore(sim), SimpleAsymmetricSemaphore(sim)))

function Base.lock(s::AsymmetricSemaphore)
    sem = s.semaphorepair[s.current_semaphore]
    lock(sem)
end

function unlock(s::AsymmetricSemaphore)
    if !(s.semaphorepair[1].unlocking || s.semaphorepair[2].unlocking)
        sem = s.semaphorepair[s.current_semaphore]
        s.current_semaphore = 3 - s.current_semaphore
        unlock(sem)
    end
end

function islocked(s::AsymmetricSemaphore)
    sem = s.semaphorepair[s.current_semaphore]
    return islocked(sem)
end
