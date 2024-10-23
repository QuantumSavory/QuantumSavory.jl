using ConcurrentSim
using ResumableFunctions
import Base: unlock, lock

"""Multiple processes can wait on this semaphore for a permission to run given by another process"""
struct AsymmetricSemaphore
    nbwaiters::Ref{Int}
    lock::Resource
end
AsymmetricSemaphore(sim) = AsymmetricSemaphore(Ref(0), Resource(sim,1,level=1)) # start locked

function Base.lock(s::AsymmetricSemaphore)
    println("calling the lock")
    return @process _lock(s.lock.env, s)
end

@resumable function _lock(sim, s::AsymmetricSemaphore)
    println("S locking") # Step 2: This is not reached
    s.nbwaiters[] += 1
    @yield lock(s.lock)
    s.nbwaiters[] -= 1
    if s.nbwaiters[] > 0
        unlock(s.lock)
    end
end

function unlock(s::AsymmetricSemaphore)
    println("S unlocking")
    if s.nbwaiters[] > 0
        unlock(s.lock)
    end
end
