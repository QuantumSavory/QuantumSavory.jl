using Test
using Random

include("../../examples/purificationMBQC/interactive.jl")

@testset "MBQC hardware-source trajectories" begin
    Random.seed!(0x4d425143)
    p = default_source_parameters
    sources = purification_sources(p)
    @test tr(express(sources.local_source.state)) ≈ 1
    @test tr(express(sources.long_source.state)) ≈ 1

    # The graph-edge mixture must preserve the *direction* of source errors,
    # including visibility-induced phase errors, under the local Clifford.
    raw_local = express(BarrettKokBellPairW(p.local_transmission_a,
        p.local_transmission_b, p.local_dark_counts, p.local_detection, p.local_visibility))
    for first in (false, true)
        placed = purification_sources(merge(p, (hadamard_first=first,)))
        to_graph = express(first ? H⊗X : I⊗(H*X))
        @test express(placed.local_source.state).data ≈
            (to_graph * raw_local * to_graph' / tr(raw_local)).data
        @test placed.local_source.fidelity ≈ sources.local_source.fidelity
        @test placed.local_source.probability == sources.local_source.probability
        @test express(placed.long_source.state).data ≈ express(sources.long_source.state).data
        @test placed.long_source.probability == sources.long_source.probability
    end
    alternate = purification_sources(merge(p, (hadamard_first=true,)))
    @test !isapprox(express(alternate.local_source.state).data, express(sources.local_source.state).data)

    raw_long = express(GenqoMultiplexedCascadedBellPairW(p.long_bsm,
        p.long_detection, p.long_transmission, p.mean_photons))
    to_bell = express(I⊗Z)
    density = to_bell * raw_long * to_bell' / tr(raw_long)
    @test express(sources.long_source.state).data ≈ density.data # zero capture noise
    # Check the channel against its Pauli action, independently of the symbolic
    # Bell-mixture implementation. Both endpoints preserve the source timing.
    paulis = [express(a⊗b) for a in (I, X, Y, Z), b in (I, X, Y, Z)]
    randomized = sum(u * density * u' for u in paulis) / 16
    for noise in (0.37, 1.0)
        captured = purification_sources(merge(p, (spin_capture_noise=noise,)))
        @test express(captured.long_source.state).data ≈
            ((1 - noise) * density + noise * randomized).data
        @test captured.long_source.probability == sources.long_source.probability
        @test captured.long_source.fidelity ≈ (1 - noise) * sources.long_source.fidelity + noise / 4
        @test express(captured.local_source.state).data ≈ express(sources.local_source.state).data
        @test captured.local_source.probability == sources.local_source.probability
    end
    @test randomized.data ≈ express((I⊗I)/4).data

    ideal_parameters = merge(p, (local_dark_counts=0.0, local_visibility=1.0,
        long_bsm=1.0, long_detection=1.0, long_transmission=1.0))
    for first in (false, true)
        placed_parameters = merge(ideal_parameters, (hadamard_first=first,))
        ideal_sources = purification_sources(placed_parameters)
        @test express(ideal_sources.local_source.state).data ≈ express(SProjector(graph_edge_states[1])).data
        for _ in 1:5
            result = purification_trial(placed_parameters, ideal_sources)
            @test result.accepted
            @test result.fidelity ≈ 1
            @test isfinite(result.duration) && result.duration > 0
        end
    end

    noisy_parameters = merge(p, (local_visibility=0.5, mean_photons=0.2, spin_capture_noise=0.35))
    noisy_sources = purification_sources(noisy_parameters)
    @test noisy_sources.local_source.fidelity < sources.local_source.fidelity
    @test noisy_sources.long_source.fidelity < sources.long_source.fidelity
    @test noisy_sources.long_source.probability > sources.long_source.probability
    history = NamedTuple[]
    for trial in 1:105
        result = purification_trial(noisy_parameters, noisy_sources)
        retain_trial!(history, merge(result, (; trial)))
    end
    @test length(history) == 100
    @test first(history).trial == 6
    @test last(history).trial == 105
    @test any(r -> r.accepted, history)
    @test any(r -> !r.accepted, history)
    @test all(r -> r.accepted ? 0 <= r.fidelity <= 1 : isnan(r.fidelity), history)
    @test all(r -> r.parameters == noisy_parameters, history)
end

@testset "MBQC GLMakie controls and snapshots" begin
    dashboard = purification_dashboard(max_runs=3)
    try
        dashboard.running[] = false
        sleep(0.1)
        @test isempty(dashboard.history[])
        on(dashboard.history) do results
            if length(results) == 1
                set_close_to!(dashboard.sliders[9], 0.08)
                set_close_to!(dashboard.sliders[10], 0.25)
                dashboard.hadamard_toggle.active[] = true
            elseif length(results) == 2
                dashboard.running[] = false
            end
        end
        dashboard.running[] = true
        @test timedwait(() -> length(dashboard.history[]) == 2 || istaskdone(dashboard.task), 180) == :ok
        @test length(dashboard.history[]) == 2
        sleep(0.1)
        @test length(dashboard.history[]) == 2 # paused, no second coordinator
        @test dashboard.history[][2].parameters.hadamard_first
        dashboard.hadamard_toggle.active[] = false
        dashboard.running[] = true
        @test timedwait(() -> istaskdone(dashboard.task), 180) == :ok
        wait(dashboard.task) # propagate any simulation or rendering failure
        @test length(dashboard.history[]) == 3
        @test dashboard.history[][1].parameters.mean_photons == default_source_parameters.mean_photons
        @test all(r -> r.parameters.mean_photons ≈ 0.08, dashboard.history[][2:3])
        @test dashboard.history[][1].parameters.spin_capture_noise == 0
        @test all(r -> r.parameters.spin_capture_noise == 0.25, dashboard.history[][2:3])
        @test [r.parameters.hadamard_first for r in dashboard.history[]] == [false, true, false]
        @test all(r -> r.input_fidelity ≈ purification_sources(r.parameters).long_source.fidelity,
            dashboard.history[])
        dashboard.clear.clicks[] += 1
        @test isempty(dashboard.history[])
    finally
        close(dashboard.screen)
        wait(dashboard.task)
    end
end
