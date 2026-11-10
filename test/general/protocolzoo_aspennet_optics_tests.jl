using Test, Random
using ConcurrentSim, Graphs, QuantumSavory
using QuantumOpticsBase: dm
using QuantumSavory.ProtocolZoo.AspenNet: Source, LocalMeasurement, Hub, Start, TimeTag, Confirmation
using QuantumSavory.ProtocolZoo: AspenNet

function optical_register(n)
    Register(fill(Qumode(), n), fill(QuantumOpticsRepr(cutoff=4), n))
end

function optical_network()
    RegisterNet(path_graph(3), [optical_register(2) for _ in 1:3];
        classical_delay=0.25, quantum_delay=0.25)
end

@testset "ASPEN-Net bosonic optics" begin
    Random.seed!(601)
    fock = AspenNet._fock_basis()
    beamsplitter = express(BeamSplitterOp(1/2), QuantumOpticsRepr(cutoff=4))
    vacuum, photon = fock[1:2]
    bell = dm((photon⊗vacuum + vacuum⊗photon)/sqrt(2))

    @testset "Complete Fock measurement and photon bunching" begin
        @test length(fock) == 5
        reg = optical_register(1)
        for number in 0:4
            initialize!(reg[1], fock[number+1])
            @test project_traceout!(reg[1], fock) == number+1
        end

        reg = optical_register(2)
        initialize!(reg[1:2], photon⊗photon)
        apply!(reg[1:2], beamsplitter)
        @test real(observable(reg[1:2], dm(photon⊗photon))) ≈ 0 atol=1e-12
        @test real(observable(reg[1:2], dm(fock[3]⊗vacuum))) ≈ 1/2
        @test real(observable(reg[1:2], dm(vacuum⊗fock[3]))) ≈ 1/2
    end

    @testset "Protocols distinguish vacuum from every nonzero occupation" begin
        net = RegisterNet([optical_register(5)])
        measurement = LocalMeasurement(net, 1)
        for number in 0:4
            initialize!(net[1][number+1], fock[number+1])
            tag!(net[1][number+1], TimeTag(number+1))
        end
        Process(measurement)
        run(get_time_tracker(net), 0.1)
        @test sort([(row.slot, row.number) for row in measurement._log]) ==
            [(number+1, Int(number > 0)) for number in 0:4]
        @test all(slot -> !isassigned(slot), net[1])

        for (first, second) in ((0, 0), (1, 0), (4, 0), (0, 4), (2, 2))
            net = optical_network()
            hub = Hub(net, 2, (1, 3))
            # Reverse the splitter to prepare definite occupations at its outputs.
            inputs = beamsplitter' * (fock[first+1]⊗fock[second+1])
            initialize!((net[1][1], net[3][1]), inputs)
            for node in (1, 3)
                put!(qchannel(net, node=>2), net[node][1])
            end
            Process(hub)
            run(get_time_tracker(net), hub.tick_duration*hub.repetitions+0.6)
            @test only(hub._log).success == (first > 0 && second == 0)
            @test all(slot -> !isassigned(slot), net[2])
        end
    end

    @testset "Default sources retain a coherent Bell pair on heralding" begin
        net = optical_network()
        sim = get_time_tracker(net)
        sources = [Source(net, node, 2) for node in (1, 3)]
        hub = Hub(net, 2, (1, 3))
        foreach(Process, [sources; [hub]]) # No destructive LocalMeasurement.
        source = first(sources)
        duration = source.tick_duration*source.repetitions
        for node in (1, 3)
            put!(messagebuffer(net, node), Tag(Start(0, 3000*source.repetitions)))
        end

        # Inspect an emitted state before its flying mode reaches the hub.
        run(sim, duration+0.125)
        @test isassigned(net[1][1])
        emitted = copy(QuantumSavory.stateof(net[1][1]).state[])
        availability = 1-(1-source.heralding_probability)^source.repetitions
        click = sum(dm(state) for state in fock[2:end])
        accepted = click⊗dm(vacuum)
        herald_probability, bell_probability = 0.0, 0.0
        # Missing emissions contribute vacuum. Sum physical branch probabilities
        # exactly so the fidelity check does not depend on sampling rare errors.
        for (left, right, weight) in (
            (emitted, emitted, availability^2),
            (emitted, vacuum⊗vacuum, availability*(1-availability)),
            (vacuum⊗vacuum, emitted, availability*(1-availability)),
        )
            reg = optical_register(4)
            initialize!((reg[1], reg[3]), left)
            initialize!((reg[2], reg[4]), right)
            apply!(reg[3:4], beamsplitter)
            herald_probability += weight*real(observable(reg[3:4], accepted))
            bell_probability += weight*real(observable(reg[1:4], bell⊗accepted))
        end
        @test 0.99 < bell_probability/herald_probability < 1

        bell_pairs = 0
        for period in 1:3000
            run(sim, period*duration+0.6)
            confirmations = [querydelete!(messagebuffer(net, node), Confirmation, period, ❓)
                for node in (1, 3)]
            @test isnothing(confirmations[1]) == isnothing(confirmations[2])
            if !isnothing(confirmations[1])
                @test confirmations[1].tag == confirmations[2].tag
                if confirmations[1].tag[3] == 1 && all(node -> isassigned(net[node][1]), (1, 3))
                    memories = (net[1][1], net[3][1])
                    fidelity = real(observable(memories, bell))
                    vacuum_probability = real(observable(memories, dm(vacuum⊗vacuum)))
                    # Anticorrelation alone would also accept a mixture of Bell
                    # phases. This projector checks the retained coherence.
                    @test fidelity+vacuum_probability ≈ 1
                    bell_pairs += isapprox(fidelity, 1)
                end
            end
            traceout!(net[1][1], net[3][1])
            for node in (1, 3)
                querydelete!(net[node], TimeTag, period)
            end
            bell_pairs >= 4 && break
        end
        @test bell_pairs >= 4
    end
end
