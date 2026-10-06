using Test, Random, Logging, InteractiveUtils, REPL
using ConcurrentSim, Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using QuantumSavory.ProtocolZoo: _aspen_repetitions, available_protocol_types

function aspen_fixture(; delay=0.0, heralding_prob=1.0, attempt_time=0.1, kwargs...)
    net = RegisterNet(path_graph(3), [Register(1, QuantumOpticsRepr()) for _ in 1:3]; classical_delay=delay)
    prot = AspenEntanglerProt(net, 1, 3, 2; heralding_prob, attempt_time, kwargs...)
    return net, prot
end

@testset "ASPEN buffered sources" begin
    repetitions = _aspen_repetitions(0.5, 0.95)
    @test repetitions == 6
    @test (1-0.5^repetitions)^2 ≥ 0.95 > (1-0.5^(repetitions-1))^2
    @test _aspen_repetitions(0.5, 0.9) == 5
    @test _aspen_repetitions(1.0, 1.0) == 1
    Random.seed!(401)
    net, p = aspen_fixture(; heralding_prob=0.5, coincidence_prob=0.95,
        central_fraction=0.0, rounds=32)
    @process p()
    run(p.sim)
    @test all(row -> row.outcome == :failure, p._log)
    @test all(row -> row.firstA in 0:6 && row.firstB in 0:6, p._log)
    @test any(row -> row.firstA > 1 || row.firstB > 1, p._log)
    @test [row.start for row in p._log] == collect(0.0:31.0)
    @test all(row -> row.release ≈ row.start + 0.6, p._log)
    @test all(slot -> !isassigned(slot) && !islocked(slot), (net[1][1], net[3][1]))
end

@testset "ASPEN threshold heralds include vacuum" begin
    Random.seed!(402)
    net, p = aspen_fixture(; central_fraction=0.5, rounds=12)
    @process p()
    run(p.sim)
    row = only(filter(row -> row.outcome == :success, p._log))
    a, b = net[1][1], net[3][1]
    @test (row.firstA, row.firstB) == (1, 1)
    @test observable((a,b), projector((Z1⊗Z2 + Z2⊗Z1)/sqrt(2))) ≈ 2/3
    @test observable((a,b), projector(Z1⊗Z1)) ≈ 1/3
    @test query(a, EntanglementCounterpart, 3, 1, row.pair_id) !== nothing
    @test query(b, EntanglementCounterpart, 1, 1, row.pair_id) !== nothing
    @test row.pair_id != NO_ENTANGLEMENT_ID
    @test !islocked(a) && !islocked(b)
end

@testset "ASPEN pair waits for both confirmations" begin
    delay(src, dst) = src == 2 ? (dst == 1 ? 0.2 : 0.6) : 0.0
    for fraction in (0.0, 1.0)
        net, p = aspen_fixture(; delay, central_fraction=fraction, photon_time=0.2)
        a, b = net[1][1], net[3][1]
        @process p()
        run(p.sim, 0.25)
        @test isassigned(a) && isassigned(b) && islocked(a) && islocked(b)
        @test query(a, EntanglementCounterpart, ❓, ❓, ❓) === nothing
        @test query(b, EntanglementCounterpart, ❓, ❓, ❓) === nothing
        run(p.sim, 0.6)
        @test islocked(a) && islocked(b) && isassigned(a) && isassigned(b)
        @test query(a, EntanglementCounterpart, ❓, ❓, ❓) === nothing
        @test query(b, EntanglementCounterpart, ❓, ❓, ❓) === nothing
        run(p.sim)
        row = only(p._log)
        @test row.herald ≈ 0.3
        @test row.complete ≈ 0.9
        @test row.outcome == (fraction == 1.0 ? :success : :failure)
        @test !islocked(a) && !islocked(b)
        @test all(node -> query(messagebuffer(net, node), AspenHerald, ❓, ❓) === nothing, (1, 3))
        if fraction == 1.0
            @test observable((a,b), projector(Z1⊗Z1)) ≈ 1.0
        else
            @test !isassigned(a) && !isassigned(b)
        end
    end
end

@testset "ASPEN missed slots keep the agreed clock" begin
    net, p = aspen_fixture(; delay=1.5, central_fraction=0.0, rounds=4)
    @process p()
    run(p.sim)
    @test [row.start for row in p._log] == [0.0, 1.0, 2.0, 3.0]
    @test [row.outcome for row in p._log] == [:failure, :late, :failure, :late]
    @test [row.release for row in p._log if row.outcome == :failure] ≈ [0.1, 2.1]
    @test all(slot -> !isassigned(slot) && !islocked(slot), (net[1][1], net[3][1]))
    net, p = aspen_fixture(; central_fraction=0.0, period=0.1, rounds=20)
    @process p()
    run(p.sim)
    @test all(row -> row.outcome == :failure, p._log)
    @test [row.release for row in p._log] ≈ 0.1 .* (1:20)
end

@testset "ASPEN pairs compose with consumers" begin
    net, p = aspen_fixture(; delay=(src,dst) -> dst == 1 ? 0.2 : 0.6, central_fraction=1.0)
    consumer = EntanglementConsumer(net, 1, 3; period=nothing)
    @process p()
    @process consumer()
    run(p.sim)
    @test only(consumer._log).t ≈ 0.7
    @test all(slot -> !isassigned(slot) && !islocked(slot), (net[1][1], net[3][1]))
    @test query(net[1][1], EntanglementCounterpart, ❓, ❓, ❓) === nothing
    @test query(net[3][1], EntanglementCounterpart, ❓, ❓, ❓) === nothing
end

@testset "ASPEN missing photons produce only vacuum heralds" begin
    Random.seed!(403)
    net, p = aspen_fixture(; heralding_prob=0.5, coincidence_prob=0.2,
        central_fraction=1.0, rounds=32)
    consumer = EntanglementConsumer(net, 1, 3; period=nothing)
    @process p()
    @process consumer()
    run(p.sim)
    @test all(row -> (row.outcome == :success) == (row.firstA > 0 || row.firstB > 0), p._log)
    @test any(row -> xor(row.firstA > 0, row.firstB > 0), p._log)
    @test any(row -> row.firstA == row.firstB == 0, p._log)
    @test length(consumer._log) == count(row -> row.outcome == :success, p._log)
    @test all(row -> row.obs1 ≈ 1 && row.obs2 ≈ 0, consumer._log)
    @test all(slot -> !isassigned(slot) && !islocked(slot), (net[1][1], net[3][1]))
end

@testset "ASPEN preserves occupied and reserved memories" begin
    for reservation in (:state, :lock, :counterpart)
        net, p = aspen_fixture(; start_time=0.1)
        a, b = net[1][1], net[3][1]
        reservation == :state && initialize!(a, Z2)
        reservation == :lock && lock(a)
        reservation == :counterpart && tag!(a, EntanglementCounterpart, 3, 1, 42)
        @process p()
        run(p.sim)
        @test only(p._log).outcome == :busy
        @test !isassigned(b) && !islocked(b)
        @test isassigned(a) == (reservation == :state)
        @test islocked(a) == (reservation == :lock)
        reservation == :state && @test observable(a, Z) ≈ -1
        reservation == :counterpart && @test query(a, EntanglementCounterpart, 3, 1, 42) !== nothing
        reservation == :lock && unlock(a)
    end
end

@testset "ASPEN protocol inspection and logging" begin
    net, p = aspen_fixture(; central_fraction=0.0)
    @test get_time_tracker(p) === get_time_tracker(net)
    @test protocol_log_context(p).nodes == (1, 3, 2)
    catalog = only(filter(entry -> entry.type === AspenEntanglerProt, available_protocol_types()))
    @test catalog.attachment_fields == (node=:centralnode,)
    @test Tag(AspenHerald(42, true)) == Tag(AspenHerald, 42, 1)
    @test occursin("success", sprint(show, AspenHerald(42, true)))
    @test occursin("failure", sprint(show, AspenHerald(42, false)))
    @test occursin("AspenEntanglerProt", sprint(show, MIME"text/html"(), p))
    logger = Test.TestLogger(min_level=Logging.Debug)
    with_logger(logger) do
        @process p()
        run(p.sim)
    end
    records = filter(record -> record.group == LOG_GROUPS.protocol, logger.logs)
    completion = only(filter(record -> get(record.kwargs, :event, nothing) == :aspen_slot_completed, records))
    @test completion.kwargs[:nodes] == (1, 3, 2)
    @test completion.kwargs[:protocol] == :AspenEntanglerProt
    @test completion.kwargs[:sim_time] == only(p._log).complete
    @test completion.kwargs[:sim_process_id] isa UInt
    for mime in (MIME"text/plain"(), MIME"text/html"())
        output = sprint(show, mime, p; context=:displaysize=>(40, 200))
        @test all(text -> occursin(text, output), ("AspenEntanglerProt", "buffered repetitions", "Release", "Complete", "failure"))
    end
    @test_throws DomainError AspenEntanglerProt(net, 1, 3, 2; heralding_prob=0.0)
    @test_throws ArgumentError AspenEntanglerProt(Simulation(), net, 1, 3, 2)
    @test_throws ArgumentError AspenEntanglerProt(net, 1, 3, 2; heralding_prob=0.5, coincidence_prob=1.0)
end
