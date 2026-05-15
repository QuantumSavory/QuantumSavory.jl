using Test
using ConcurrentSim
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ResumableFunctions

function add_superdense_pair!(net, slot)
    initialize!((net[1, slot], net[2, slot]), StabilizerState("ZZ XX"); time=now(get_time_tracker(net)))
    tag!(net[1, slot], EntanglementCounterpart, 2, slot)
    tag!(net[2, slot], EntanglementCounterpart, 1, slot)
end

function take_delivery!(net, bits, uuid)
    bit1, bit2 = bits
    querydelete!(messagebuffer(net, 2), SuperdenseDelivery, 1, 2, bit1, bit2, uuid, ❓)
end

@testset "SuperdenseCodingProt" begin
    @testset "constructs message and delivery tags" begin
        msg = SuperdenseMessage(1, 2, 0, 1, 7)
        @test msg.bits == (0, 1)
        @test SuperdenseMessage(src=1, dst=2, bits=(1, 0), uuid=8).bits == (1, 0)

        delivery = SuperdenseDelivery(1, 2, 1, 0, 9, 1.5)
        @test delivery.bits == (1, 0)
        @test SuperdenseDelivery(src=1, dst=2, bits=(0, 1), uuid=10, finish_time=2.5).finish_time == 2.5

        @test QuantumSavory.ProtocolZoo._is_superdense_bit(:bad) === false
        @test QuantumSavory.ProtocolZoo._is_superdense_uuid(11) === true
        @test QuantumSavory.ProtocolZoo._is_superdense_uuid(:bad) === false
    end

    @testset "delivers all two-bit payloads and consumes the Bell pairs" begin
        net = RegisterNet([Register(4), Register(5)]; quantum_delay=0.25)
        sim = get_time_tracker(net)
        for slot in 1:4
            add_superdense_pair!(net, slot)
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=5, period=0.05)
        @process prot()

        payloads = [(0, 0), (0, 1), (1, 0), (1, 1)]
        for (uuid, bits) in enumerate(payloads)
            put!(net[1], SuperdenseMessage(1, 2, bits, uuid))
        end

        run(sim, 5.0)

        for (uuid, bits) in enumerate(payloads)
            delivery = take_delivery!(net, bits, uuid)
            @test !isnothing(delivery)
            @test delivery.tag[7] >= 0.25
        end
        @test length(prot._log) == 4
        @test sort([entry.bits for entry in prot._log]) == payloads
        for slot in 1:4
            @test isnothing(query(net[1, slot], EntanglementCounterpart, 2, slot))
            @test isnothing(query(net[2, slot], EntanglementCounterpart, 1, slot))
            @test !isassigned(net[1, slot])
            @test !isassigned(net[2, slot])
        end
        @test !isassigned(net[2, 5])
    end

    @testset "respects the direct quantum-channel delay" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=3.0)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=0.05)
        @process prot()
        put!(net[1], SuperdenseMessage(1, 2, (1, 0), 7))

        run(sim, 2.9)
        @test take_delivery!(net, (1, 0), 7) === nothing

        run(sim, 3.1)
        delivery = take_delivery!(net, (1, 0), 7)
        @test !isnothing(delivery)
        @test delivery.tag[7] == 3.0
        @test only(prot._log).finish_time == 3.0
    end

    @testset "requires a direct quantum channel" begin
        net = RegisterNet([Register(1), Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)

        prot = SuperdenseCodingProt(net, 1, 3; chooseslotB=2)
        @process prot()

        err = try
            run(sim, 0.1)
            nothing
        catch err
            err
        end
        @test err isa ArgumentError
        @test occursin("direct quantum channel", sprint(showerror, err))
    end

    @testset "waits until matching entanglement exists" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=0.05)
        @process prot()
        put!(net[1], SuperdenseMessage(1, 2, (0, 1), 9))

        run(sim, 1.0)
        @test take_delivery!(net, (0, 1), 9) === nothing

        add_superdense_pair!(net, 1)
        run(sim, 2.0)

        delivery = take_delivery!(net, (0, 1), 9)
        @test !isnothing(delivery)
        @test delivery.tag[7] >= 1.1
        @test only(prot._log).bits == (0, 1)
    end

    @testset "skips one-sided stale entanglement candidates" begin
        net = RegisterNet([Register(2), Register(3)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        initialize!(net[1, 2])
        tag!(net[1, 2], EntanglementCounterpart, 2, 2)

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=3, period=0.05)
        @process prot()
        put!(net[1], SuperdenseMessage(1, 2, (0, 1), 16))

        run(sim, 2.0)

        delivery = take_delivery!(net, (0, 1), 16)
        @test !isnothing(delivery)
        @test only(prot._log).send_slot == 1
        @test !isnothing(query(net[1, 2], EntanglementCounterpart, 2, 2))
    end

    @testset "skips stale Bob-side reciprocal candidates" begin
        net = RegisterNet([Register(1), Register(3)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        initialize!(net[2, 2])
        tag!(net[2, 2], EntanglementCounterpart, 1, 1)

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=3, period=0.05)
        @process prot()
        put!(net[1], SuperdenseMessage(1, 2, (1, 1), 19))

        run(sim, 2.0)

        delivery = take_delivery!(net, (1, 1), 19)
        @test !isnothing(delivery)
        @test only(prot._log).entangled_slot == 1
        @test !isnothing(query(net[2, 2], EntanglementCounterpart, 1, 1))
    end

    @testset "waits on reciprocal entanglement tag events when period is nothing" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        initialize!((net[1, 1], net[2, 1]), StabilizerState("ZZ XX"); time=now(sim))
        tag!(net[1, 1], EntanglementCounterpart, 2, 1)

        @resumable function add_missing_counterpart(sim, slot)
            @yield timeout(sim, 0.5)
            tag!(slot, EntanglementCounterpart, 1, 1)
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=nothing)
        @process prot()
        @process add_missing_counterpart(sim, net[2, 1])
        put!(net[1], SuperdenseMessage(1, 2, (1, 1), 10))

        run(sim, 0.4)
        @test take_delivery!(net, (1, 1), 10) === nothing

        run(sim, 2.0)
        delivery = take_delivery!(net, (1, 1), 10)
        @test !isnothing(delivery)
        @test delivery.tag[7] >= 0.6
    end

    @testset "retries locked entanglement resources when period is nothing" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        lock(net[1, 1])

        @resumable function release_locked_pair(sim, slot)
            @yield timeout(sim, 0.5)
            unlock(slot)
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=nothing, resource_retry_time=0.1)
        @process prot()
        @process release_locked_pair(sim, net[1, 1])
        put!(net[1], SuperdenseMessage(1, 2, (0, 0), 20))

        run(sim, 0.4)
        @test take_delivery!(net, (0, 0), 20) === nothing

        run(sim, 2.0)
        delivery = take_delivery!(net, (0, 0), 20)
        @test !isnothing(delivery)
        @test delivery.tag[7] >= 0.6
        @test !islocked(net[1, 1])
    end

    @testset "retries receive-slot availability when period is nothing" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        initialize!(net[2, 2])

        @resumable function free_receive_slot(sim, slot)
            @yield timeout(sim, 0.5)
            traceout!(slot)
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=nothing, receive_slot_retry_time=0.1)
        @process prot()
        @process free_receive_slot(sim, net[2, 2])
        put!(net[1], SuperdenseMessage(1, 2, (1, 0), 11))

        run(sim, 0.4)
        @test take_delivery!(net, (1, 0), 11) === nothing

        run(sim, 2.0)
        delivery = take_delivery!(net, (1, 0), 11)
        @test !isnothing(delivery)
        @test delivery.tag[7] >= 0.6
    end

    @testset "retries receive-slot availability on finite periods" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        initialize!(net[2, 2])

        @resumable function free_receive_slot(sim, slot)
            @yield timeout(sim, 0.5)
            traceout!(slot)
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=0.05)
        @process prot()
        @process free_receive_slot(sim, net[2, 2])
        put!(net[1], SuperdenseMessage(1, 2, (0, 0), 18))

        run(sim, 0.4)
        @test take_delivery!(net, (0, 0), 18) === nothing

        run(sim, 2.0)
        delivery = take_delivery!(net, (0, 0), 18)
        @test !isnothing(delivery)
        @test delivery.tag[7] >= 0.6
    end

    @testset "ignores requests for other endpoints" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=0.05)
        @process prot()
        put!(net[1], SuperdenseMessage(2, 1, (0, 1), 12))
        put!(net[1], SuperdenseMessage(1, 2, (1, 0), 13))

        run(sim, 2.0)

        @test !isnothing(take_delivery!(net, (1, 0), 13))
        @test query(messagebuffer(net, 1), SuperdenseMessage, 2, 1, 0, 1, 12) !== nothing
    end

    @testset "revalidates the receive slot after lock acquisition" begin
        net = RegisterNet([Register(1), Register(3)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        stole_receive_slot = Ref(false)

        function steal_first_receive_slot(idx)
            if idx == 2 && !stole_receive_slot[]
                stole_receive_slot[] = true
                initialize!(net[2, 2])
            end
            return idx >= 2
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=steal_first_receive_slot, period=0.05)
        @process prot()
        put!(net[1], SuperdenseMessage(1, 2, (0, 1), 14))

        run(sim, 2.0)

        delivery = take_delivery!(net, (0, 1), 14)
        @test stole_receive_slot[]
        @test !isnothing(delivery)
        @test delivery.tag[7] >= 0.1
        @test isassigned(net[2, 2])
        @test !islocked(net[1, 1])
        @test !islocked(net[2, 1])
        @test !islocked(net[2, 2])
        @test !islocked(net[2, 3])
    end

    @testset "revalidates a request after queued locks" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        request_deleted = Ref(false)
        receive_slot_pinned = Ref(false)

        @resumable function delete_selected_request(sim, slot)
            deleted = querydelete!(messagebuffer(net, 1), SuperdenseMessage, 1, 2, 1, 0, 15)
            request_deleted[] = !isnothing(deleted)
            @yield timeout(sim, 0.2)
            unlock(slot)
        end

        function pin_receive_slot(idx)
            if idx == 2 && !receive_slot_pinned[]
                request(net[2, 2])
                receive_slot_pinned[] = true
                @process delete_selected_request(sim, net[2, 2])
            end
            return idx == 2
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=pin_receive_slot, period=0.05)
        @process prot()
        put!(net[1], SuperdenseMessage(1, 2, (1, 0), 15))

        run(sim, 1.0)

        @test request_deleted[]
        @test take_delivery!(net, (1, 0), 15) === nothing
        @test !isnothing(query(net[1, 1], EntanglementCounterpart, 2, 1))
        @test !isnothing(query(net[2, 1], EntanglementCounterpart, 1, 1))
        @test !islocked(net[1, 1])
        @test !islocked(net[2, 1])
        @test !islocked(net[2, 2])
    end

    @testset "encodes at the current simulation time" begin
        net = RegisterNet([Register(1), Register(2)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)

        @resumable function request_later(sim)
            @yield timeout(sim, 0.5)
            put!(net[1], SuperdenseMessage(1, 2, (1, 0), 17))
        end

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=2, period=0.05)
        @process prot()
        @process request_later(sim)

        run(sim, 2.0)

        delivery = take_delivery!(net, (1, 0), 17)
        @test !isnothing(delivery)
        @test only(prot._log).start_time == 0.5
        @test net[1].accesstimes[1] == 0.5
    end

    @testset "serializes concurrent protocol use of the same quantum channel" begin
        net = RegisterNet([Register(2), Register(4)]; quantum_delay=1.0)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)
        add_superdense_pair!(net, 2)

        prot1 = SuperdenseCodingProt(net, 1, 2; chooseslotB=3, period=0.05)
        prot2 = SuperdenseCodingProt(net, 1, 2; chooseslotB=4, period=0.05)
        @process prot1()
        @process prot2()
        put!(net[1], SuperdenseMessage(1, 2, (0, 0), 21))
        put!(net[1], SuperdenseMessage(1, 2, (1, 1), 22))

        run(sim, 3.0)

        delivery1 = take_delivery!(net, (0, 0), 21)
        delivery2 = take_delivery!(net, (1, 1), 22)
        @test !isnothing(delivery1)
        @test !isnothing(delivery2)
        @test sort([delivery1.tag[7], delivery2.tag[7]]) == [1.0, 2.0]
        @test length(prot1._log) + length(prot2._log) == 2
    end

    @testset "rejects non-bit payloads" begin
        @test_throws ArgumentError SuperdenseMessage(1, 2, (2, 0), 1)
        @test_throws ArgumentError SuperdenseDelivery(1, 2, (0, -1), 1, 0.0)
    end

    @testset "ignores raw malformed request tags" begin
        net = RegisterNet([Register(2), Register(3)]; quantum_delay=0.1)
        sim = get_time_tracker(net)
        add_superdense_pair!(net, 1)

        prot = SuperdenseCodingProt(net, 1, 2; chooseslotB=3, period=0.05)
        @process prot()
        put!(net[1], Tag(SuperdenseMessage, 1, 2, 2, 0, 99))
        put!(net[1], Tag(SuperdenseMessage, 1, 2, 0, 1, 99.0))
        put!(net[1], SuperdenseMessage(1, 2, (1, 1), 100))

        run(sim, 2.0)

        @test !isnothing(take_delivery!(net, (1, 1), 100))
        @test query(messagebuffer(net, 1), SuperdenseMessage, 1, 2, 2, 0, 99) !== nothing
        @test query(messagebuffer(net, 1), Tag(SuperdenseMessage, 1, 2, 0, 1, 99.0)) !== nothing
        @test take_delivery!(net, (0, 0), 99) === nothing
        @test take_delivery!(net, (0, 1), 99) === nothing
    end
end
