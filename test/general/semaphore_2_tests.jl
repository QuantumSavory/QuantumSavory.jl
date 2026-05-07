using Test
using QuantumSavory
using QuantumSavory: SimpleAsymmetricSemaphore
using ConcurrentSim
using ResumableFunctions
import Base: lock, unlock

# Regression probe for the first semaphore race reported in PR 383:
# https://github.com/QuantumSavory/QuantumSavory.jl/pull/383
#
# The issue report describes a lost wake-up in SimpleAsymmetricSemaphore. Before
# the proposed fix, `lock(semaphore)` returned a scheduled `_lock` process, but
# `nbwaiters` was incremented only after that process actually got a scheduler
# turn. That left a same-timestamp window where a caller had already requested
# the lock, but `unlock(semaphore)` still saw `nbwaiters == 0` and dropped the
# signal. In real protocols this appears as `onchange(reg)` hanging even though
# a matching `tag!` already happened.
#
# This test keeps the interleaving minimal and direct. The waiter and unlocker
# both resume at simulation time 1. The waiter is scheduled first, so it creates
# the lock process first. The newly created lock process is queued behind the
# unlocker's already scheduled timeout at the same timestamp. A correct
# semaphore must still count the waiter synchronously before the unlocker runs.
@testset "SimpleAsymmetricSemaphore same-timestamp wake after lock request" begin
    sim = Simulation()
    semaphore = SimpleAsymmetricSemaphore(sim)
    log = Symbol[]

    @resumable function waiter(sim)
        @yield timeout(sim, 1)
        push!(log, :wait_requested)
        @yield lock(semaphore)
        push!(log, :wait_finished)
    end

    @resumable function unlocker(sim)
        @yield timeout(sim, 1)
        push!(log, :unlock)
        unlock(semaphore)
    end

    @process waiter(sim)
    @process unlocker(sim)

    run(sim, 2)

    @test log == [:wait_requested, :unlock, :wait_finished]
    @test semaphore.nbwaiters == 0
    @test !semaphore.unlocking
end
