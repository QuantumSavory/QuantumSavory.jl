using Test
using QuantumSavory
using QuantumSavory: AsymmetricSemaphore
using ConcurrentSim
using ResumableFunctions
import Base: lock, unlock

# Regression probe for the second semaphore race discussed in PR 383:
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383#issuecomment-4371250761
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383#issuecomment-4386204614
#
# The issue report describes dropped wake-ups in the parent AsymmetricSemaphore.
# The pair design uses one child SimpleAsymmetricSemaphore for the current
# waiting side and the other child for waiters that immediately re-lock during a
# wake-up cascade. The older parent `unlock` guard returned silently whenever
# either child was already cascading. That avoided feeding a running cascade,
# but it also dropped real wake-ups that arrived after waiters had re-locked
# into the current child.
#
# This test creates that state without using MessageBuffer or Register. The
# first unlock starts a cascade on child 1. The first waiter wakes, immediately
# locks again onto the now-current child 2, and schedules a second unlock at the
# same simulation timestamp. The second unlock is intentionally issued while the
# first child is still cascading and while the current child already has a
# waiter. A correct parent semaphore must remember that wake-up and replay it
# after the first cascade drains.
@testset "AsymmetricSemaphore queues parent unlock during child cascade" begin
    sim = Simulation()
    semaphore = AsymmetricSemaphore(sim)
    log = Symbol[]
    saw_cascade = Ref(false)
    saw_current_waiter = Ref(false)

    @resumable function second_unlock(sim)
        @yield timeout(sim, 0)
        saw_cascade[] = any(s.unlocking for s in semaphore.semaphorepair)
        saw_current_waiter[] = QuantumSavory.nbwaiters(semaphore) == 1
        unlock(semaphore)
        push!(log, :second_unlock)
    end

    function relock_and_schedule_unlock(sim)
        p = lock(semaphore)
        @process second_unlock(sim)
        return p
    end

    @resumable function rewaiter(sim)
        @yield lock(semaphore)
        push!(log, :first_wake)
        @yield relock_and_schedule_unlock(sim)
        push!(log, :second_wake)
    end

    @resumable function passive_waiter(sim, i)
        @yield lock(semaphore)
        push!(log, Symbol(:passive_wake_, i))
    end

    @resumable function first_unlock(sim)
        @yield timeout(sim, 1)
        unlock(semaphore)
        push!(log, :first_unlock)
    end

    @process rewaiter(sim)
    @process passive_waiter(sim, 1)
    @process passive_waiter(sim, 2)
    @process first_unlock(sim)

    run(sim, 2)

    @test saw_cascade[]
    @test saw_current_waiter[]
    @test log == [
        :first_unlock,
        :first_wake,
        :passive_wake_1,
        :second_unlock,
        :passive_wake_2,
        :second_wake,
    ]
end
