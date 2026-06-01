using Test
using QuantumSavory
using ConcurrentSim
using ResumableFunctions
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: EntanglementCounterpart, EntanglementHistory, EntanglementUpdateX

@resumable function release_initial_lock(sim, slot)
    @yield timeout(sim, 1.0)
    unlock(slot)
end

@resumable function traceout_if_tracker_dropped_lock_gap(sim, slot, gap_observed)
    @yield lock(slot)

    old_counterpart = query(slot, EntanglementCounterpart, 2, 1)
    new_counterpart = query(slot, EntanglementCounterpart, 3, 1)
    if isnothing(old_counterpart) && isnothing(new_counterpart)
        gap_observed[] = true
        traceout!(slot)
    end

    unlock(slot)
end

@testset "EntanglementTracker forwards history updates without waiting on an empty slot lock" begin
    net = RegisterNet([Register(5) for _ in 1:4]; classical_delay=0.0)
    sim = get_time_tracker(net)
    localslot = net[2][2]

    # This is the reduced simultaneous-swap case: the physical qubit at the
    # local slot has already been swapped away, but the slot still carries the
    # history metadata needed to forward a delayed update to the new endpoint.
    tag!(localslot, EntanglementHistory, 1, 5, 4, 3, 1)
    put!(messagebuffer(net, 2), EntanglementUpdateX, 1, 5, 2, 3, 4, 1)

    lock(localslot)
    @process EntanglementTracker(sim, net, 2)()
    @process release_initial_lock(sim, localslot)

    run(sim, 0.5)

    forwarded = query(messagebuffer(net, 4), EntanglementUpdateX, ❓, ❓, ❓, ❓, ❓, ❓)
    @test !isnothing(forwarded)
    @test forwarded.tag == Tag(EntanglementUpdateX, 1, 5, 3, 3, 4, 1)
    @test !isnothing(query(localslot, EntanglementHistory, 3, 4, 4, 3, 1))
    @test islocked(localslot)

    run(sim, 1.0)
    @test !islocked(localslot)
end

@testset "EntanglementTracker keeps consumed counterpart locked until update" begin
    net = RegisterNet([Register(1), Register(1), Register(1)])
    sim = get_time_tracker(net)
    localslot = net[1][1]
    gap_observed = Ref(false)

    initialize!(localslot)
    tag!(localslot, EntanglementCounterpart, 2, 1)
    put!(messagebuffer(net, 1), Tag(EntanglementUpdateX, 2, 1, 1, 3, 1, 1))

    lock(localslot)
    @process EntanglementTracker(sim, net, 1)()
    @process traceout_if_tracker_dropped_lock_gap(sim, localslot, gap_observed)
    @process release_initial_lock(sim, localslot)

    run_error = try
        run(sim, 2.0)
        nothing
    catch err
        err
    end

    @test run_error === nothing
    @test !gap_observed[]
    @test isassigned(localslot)
    @test isnothing(query(localslot, EntanglementCounterpart, 2, 1))
    @test !isnothing(query(localslot, EntanglementCounterpart, 3, 1))
    @test !islocked(localslot)
end
