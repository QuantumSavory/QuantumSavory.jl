using Test, Random, Logging
using QuantumSavory, QuantumSavory.ProtocolZoo
using ConcurrentSim, ResumableFunctions, Graphs
import InteractiveUtils, REPL

function aspen_fixture(; rounds=1, central_fraction=1.0, quantum_delay=0.02,
        coincidence_window=0.1, heralding_prob=1.0, coincidence_prob=1.0)
    schedule = AspenSchedule(; heralding_prob, coincidence_prob, attempt_time=0.01,
        period=0.5, rounds, arrival_timeout=0.1, coincidence_window, acknowledgement_timeout=0.2)
    net = RegisterNet(star_graph(3), [Register(2, QuantumOpticsRepr()) for _ in 1:3];
        quantum_delay, classical_delay=0.02)
    a = AspenSourceProt(net, 2, 1; schedule, central_fraction)
    b = AspenSourceProt(net, 3, 1; schedule, central_fraction)
    central = AspenCentralProt(net, 1, 2, 3; schedule)
    return net, get_time_tracker(net), a, b, central
end

@testset "ASPEN buffer depth and timing contract" begin
    @test AspenSchedule(heralding_prob=1, coincidence_prob=1).repetitions == 1
    @test AspenSchedule(heralding_prob=0.5, coincidence_prob=0.5625).repetitions == 2
    @test AspenSchedule(heralding_prob=0.5, coincidence_prob=nextfloat(0.5625)).repetitions == 3
    @test_throws DomainError AspenSchedule(heralding_prob=0)
    @test_throws ArgumentError AspenSchedule(coincidence_prob=1)
    @test_throws ArgumentError AspenSchedule(period=0.1)
    @test_throws ArgumentError AspenSchedule(arrival_timeout=0.3)
    @test_throws ArgumentError aspen_fixture(quantum_delay=0.1)
    net, sim, a, b, central = aspen_fixture()
    @test_throws ArgumentError AspenSourceProt(Simulation(), net, 2, 1; schedule=a.schedule)
    @test get_time_tracker(a) === get_time_tracker(central) === sim
    @test protocol_log_context(a).nodes == (2, 1)
    @test protocol_log_context(central).nodes == (1, 2, 3)
    catalog = ProtocolZoo.available_protocol_types()
    @test all(T -> any(entry -> entry.type === T, catalog), (AspenSourceProt, AspenCentralProt))
    herald = AspenHerald(1, 2, 3, true, 1, 42)
    @test Tag(herald) == Tag(AspenHerald, 1, 2, 3, 1, 1, 42)
    @test occursin("success", sprint(show, herald))
end

@testset "ASPEN photons and heralds travel on separate channels" begin
    net, sim, a, b, central = aspen_fixture()
    @process a()
    @process b()
    @process central()
    run(sim, 0.02)
    # The flying modes have left their source but have not reached the central slots.
    @test all(isassigned(net[node][1]) && !isassigned(net[node][2]) for node in (2, 3))
    @test all(!isassigned(slot) for slot in net[1])
    run(sim, 0.04)
    @test all(isassigned, net[1])
    run(sim, 0.12)
    @test all(!isassigned, net[1])
    @test isempty(messagebuffer(net, 2).buffer)
    run(sim, 0.14)
    @test !isnothing(query(messagebuffer(net, 2), AspenHerald, 1, 1, 3, 1, ❓, ❓))
    @test isnothing(query(net[2][1], EntanglementCounterpart, ❓, ❓, ❓))
    @test_logs (:debug, "ASPEN round completed") min_level=Logging.Debug match_mode=:any run(sim, 0.22)
    counterpart = query(net[2][1], EntanglementCounterpart, 3, 1, ❓)
    @test counterpart.tag[4] != 0
    @test !isnothing(query(net[3][1], EntanglementCounterpart, 2, 1, counterpart.tag[4]))
    @test isempty(messagebuffer(net, 2).buffer)
    @test all(!islocked(slot) for register in net.registers for slot in register)
    # Sending both photons heralds vacuum with threshold detectors.
    @test observable((net[2][1], net[3][1]), Z⊗Z) ≈ 1
end

@testset "ASPEN clears partial attempts without stealing the next round" begin
    net, sim, a, b, central = aspen_fixture(rounds=2)
    initialize!(net[3][1], Z1)
    @process a()
    @process b()
    @process central()
    run(sim, 0.02)
    @test isassigned(net[3][1]) && !islocked(net[3][1])
    run(sim, 0.3)
    @test only(central._log).outcome == :timeout
    @test !isassigned(net[2][1])
    @test all(!isassigned, net[1])
    @test isassigned(net[3][1])
    traceout!(net[3][1])
    run(sim, 0.8)
    @test last(central._log).outcome == :success
    @test last(a._log).pair_id == last(b._log).pair_id != 0
    net, sim, a, b, central = aspen_fixture(
        quantum_delay=(src, dst) -> src == 3 ? 0.08 : 0.02, coincidence_window=0.06)
    @process a()
    @process b()
    @process central()
    run(sim, 0.3)
    @test only(central._log).outcome == :success
end

@testset "ASPEN missing acknowledgements, failed clicks, and arrival mismatch" begin
    net, sim, a, b, central = aspen_fixture()
    @process a()
    run(sim, 0.3)
    @test only(a._log).outcome == :timeout
    @test all(!isassigned, net[2])
    @test all(!islocked, net[2])
    for kwargs in ((central_fraction=0.0,),
            (quantum_delay=(src, dst) -> src == 3 ? 0.08 : 0.02, coincidence_window=0.03))
        net, sim, a, b, central = aspen_fixture(; rounds=3, kwargs...)
        @process a()
        @process b()
        @process central()
        run(sim, 1.3)
        expected = haskey(kwargs, :central_fraction) ? :failure : :mismatch
        @test all(entry -> entry.outcome == expected, central._log)
        @test all(!isassigned(slot) && !islocked(slot) for reg in net.registers for slot in reg)
        @test all(isempty(messagebuffer(net, node).buffer) for node in (2, 3))
    end
end

@testset "ASPEN corrected heralds compose with EntanglementConsumer" begin
    Random.seed!(238)
    net, sim, a, b, central = aspen_fixture(rounds=40, central_fraction=0.2)
    consumer = EntanglementConsumer(net, 2, 3; period=0.01)
    @process a()
    @process b()
    @process central()
    @process consumer()
    run(sim, 20.0)
    @test length(consumer._log) == count(entry -> entry.outcome == :success, central._log)
    @test any(entry -> entry.obs2 ≈ 1, consumer._log)
    @test all(entry -> entry.obs2 ≈ 1 || entry.obs2 ≈ 0, consumer._log)
    @test all(entry -> entry.obs1 ≈ 1-2entry.obs2, consumer._log)
    @test all(!isassigned(slot) for reg in net.registers for slot in reg)
end

@testset "ASPEN retains the first heralded pulse within each buffer" begin
    Random.seed!(162)
    net, sim, a, b, central = aspen_fixture(rounds=12, central_fraction=0,
        heralding_prob=0.5, coincidence_prob=0.5625)
    @process a()
    @process b()
    @process central()
    run(sim, 6.0)
    @test Set(entry.first for entry in a._log) == Set(0:2)
    @test any(entry -> entry.outcome == :no_photon, a._log)
    @test all(entry -> entry.release ≈ entry.start + 0.02, a._log)
end
