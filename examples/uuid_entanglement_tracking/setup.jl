using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo

const UUID_TRACKING_PAIR = StabilizerState("ZZ XX")

function example_uuid_generator(ids...)
    remaining = collect(ids)
    return () -> popfirst!(remaining)
end

function run_uuid_tracking_demo()
    net = RegisterNet([Register(1), Register(2), Register(1)]; classical_delay=1e-9)
    sim = get_time_tracker(net)

    entangler_left = EntanglerProtUUID(
        net,
        1,
        2;
        success_prob=1.0,
        rounds=1,
        chooseslotA=1,
        chooseslotB=1,
        uuid_generator=example_uuid_generator(11),
    )
    entangler_right = EntanglerProtUUID(
        net,
        2,
        3;
        success_prob=1.0,
        rounds=1,
        chooseslotA=2,
        chooseslotB=1,
        uuid_generator=example_uuid_generator(22),
    )
    swapper = SwapperProtUUID(net, 2; nodeL=1, nodeH=3, rounds=1, uuid_generator=example_uuid_generator(33))

    for node in vertices(net)
        @process EntanglementTrackerUUID(net, node)()
    end
    @process entangler_left()
    @process entangler_right()
    run(sim, 1.0)
    @process swapper()
    run(sim, 2.0)

    return (
        xx = real(observable((net[1, 1], net[3, 1]), X⊗X)),
        zz = real(observable((net[1, 1], net[3, 1]), Z⊗Z)),
        left_tag = query(net[1, 1], EntanglementUUID, 33, 3, 1),
        right_tag = query(net[3, 1], EntanglementUUID, 33, 1, 1),
    )
end

function run_history_tracking_demo()
    net = RegisterNet([Register(1), Register(2), Register(1)]; classical_delay=1e-9)
    sim = get_time_tracker(net)

    entangler_left = EntanglerProt(net, 1, 2; success_prob=1.0, rounds=1, chooseslotA=1, chooseslotB=1)
    entangler_right = EntanglerProt(net, 2, 3; success_prob=1.0, rounds=1, chooseslotA=2, chooseslotB=1)
    swapper = SwapperProt(net, 2; nodeL=1, nodeH=3, rounds=1)

    for node in vertices(net)
        @process EntanglementTracker(net, node)()
    end
    @process entangler_left()
    @process entangler_right()
    run(sim, 1.0)
    @process swapper()
    run(sim, 2.0)

    return (
        xx = real(observable((net[1, 1], net[3, 1]), X⊗X)),
        zz = real(observable((net[1, 1], net[3, 1]), Z⊗Z)),
        left_tag = query(net[1, 1], EntanglementCounterpart, 3, 1),
        right_tag = query(net[3, 1], EntanglementCounterpart, 1, 1),
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    uuid_result = run_uuid_tracking_demo()
    history_result = run_history_tracking_demo()

    @info "UUID tracker" xx=uuid_result.xx zz=uuid_result.zz left_tag=uuid_result.left_tag.tag right_tag=uuid_result.right_tag.tag
    @info "History tracker" xx=history_result.xx zz=history_result.zz left_tag=history_result.left_tag.tag right_tag=history_result.right_tag.tag

    @assert uuid_result.xx ≈ 1.0
    @assert uuid_result.zz ≈ 1.0
    @assert history_result.xx ≈ 1.0
    @assert history_result.zz ≈ 1.0
end
