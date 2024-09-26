using QuantumSavory: AsymmetricSemaphore
using Test
using ConcurrentSim
using ResumableFunctions
import Base: unlock, lock

@testset "AsymmetricSemaphore functionality" begin
    sim = Simulation()
    waiter = AsymmetricSemaphore(sim)
    log = []

    @resumable function trigger(sim)
        push!(log, (now(sim), "t: start"))
        @yield timeout(sim, 10)
        push!(log, (now(sim), "t: waited 10"))
        unlock(waiter)
        push!(log, (now(sim), "t: first trigger"))
        @yield timeout(sim, 20)
        push!(log, (now(sim), "t: waited 20"))
        unlock(waiter)
        push!(log, (now(sim), "t: second trigger"))
        @yield timeout(sim, 15)
        push!(log, (now(sim), "t: waited 15"))
        unlock(waiter)
        push!(log, (now(sim), "t: third trigger"))
        push!(log, (now(sim), "t: end"))
    end

    @resumable function proc1(sim)
        push!(log, (now(sim), "proc1: start"))
        @yield lock(waiter)
        push!(log, (now(sim), "proc1: first lock"))
        @yield lock(waiter)
        push!(log, (now(sim), "proc1: second lock"))
        @yield timeout(sim, 10)
        push!(log, (now(sim), "proc1: waited 10"))
        @yield lock(waiter) 
        push!(log, (now(sim), "proc1: third lock"))
        push!(log, (now(sim), "proc1: end"))
    end

    @resumable function proc2(sim)
        push!(log, (now(sim), "proc2: start"))
        @yield lock(waiter)
        push!(log, (now(sim), "proc2: first lock"))
        @yield timeout(sim, 25)
        push!(log, (now(sim), "proc2: waited 25"))
        @yield lock(waiter)
        push!(log, (now(sim), "proc2: second lock")) # should be after third trigger
        push!(log, (now(sim), "proc2: end"))
    end

    @process trigger(sim)
    @process proc1(sim)
    @process proc2(sim)

    run(sim)


    expected_log = [
        (0.0, "t: start"),
        (0.0, "proc1: start"),
        (0.0, "proc2: start"),
        (10.0, "t: waited 10"),
        (10.0, "t: first trigger"),
        (10.0, "proc1: first lock"),
        (10.0, "proc2: first lock"),
        (30.0, "t: waited 20"),
        (30.0, "t: second trigger"),
        (30.0, "proc1: second lock"),
        (35.0, "proc2: waited 25"),
        (40.0, "proc1: waited 10"),
        (45.0, "t: waited 15"),
        (45.0, "t: third trigger"),
        (45.0, "t: end"),
        (45.0, "proc2: second lock"),  
        (45.0, "proc2: end"),
        (45.0, "proc1: third lock"),
        (45.0, "proc1: end")
    ]


    @test length(log) == length(expected_log)

    for i in 1:length(log)
        @test log[i] == expected_log[i]
    end

end

@testset "Multiple AsymmetricSemaphores" begin
    sim = Simulation()
    waiter1 = AsymmetricSemaphore(sim)
    waiter2 = AsymmetricSemaphore(sim)
    log = []

    @resumable function trigger(sim)
        push!(log, (now(sim), "t: start"))
        @yield timeout(sim, 10)
        push!(log, (now(sim), "t: waited 10"))
        unlock(waiter1)
        push!(log, (now(sim), "t: unlock first waiter"))
        @yield timeout(sim, 5)
        push!(log, (now(sim), "t: waited 5"))
        unlock(waiter2)
        push!(log, (now(sim), "t: unlock second waiter"))
        push!(log, (now(sim), "t: end"))
    end

    @resumable function proc1(sim) 
        push!(log, (now(sim), "proc1: start"))
        @yield lock(waiter1) | lock(waiter2)
        push!(log, (now(sim), "proc1: got a lock"))
        push!(log, (now(sim), "proc1: end"))
    end

    @resumable function proc2(sim)
        push!(log, (now(sim), "proc2: start"))
        @yield lock(waiter1) & lock(waiter2)
        push!(log, (now(sim), "proc2: got both locks"))
        push!(log, (now(sim), "proc2: end"))
    end
    @process trigger(sim)
    @process proc1(sim)
    @process proc2(sim)

    run(sim)

    expected_log = [
    (0.0, "t: start"),
    (0.0, "proc1: start"),
    (0.0, "proc2: start"),
    (10.0, "t: waited 10"),
    (10.0, "t: unlock first waiter"),
    (10.0, "proc1: got a lock"),
    (10.0, "proc1: end"),
    (15.0, "t: waited 5"),
    (15.0, "t: unlock second waiter"),
    (15.0, "t: end"),
    (15.0, "proc2: got both locks"),
    (15.0, "proc2: end")
    ]
    
    @test length(log) == length(expected_log)

    for i in 1:length(log)
        @test log[i] == expected_log[i]
    end
end
