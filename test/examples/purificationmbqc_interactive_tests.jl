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
    to_graph = express(I⊗(H*X))
    @test express(sources.local_source.state).data ≈
        (to_graph * raw_local * to_graph' / tr(raw_local)).data

    ideal_parameters = merge(p, (local_dark_counts=0.0, local_visibility=1.0,
        long_bsm=1.0, long_detection=1.0, long_transmission=1.0))
    ideal_sources = purification_sources(ideal_parameters)
    for _ in 1:5
        result = purification_trial(ideal_parameters, ideal_sources)
        @test result.accepted
        @test result.fidelity ≈ 1
        @test isfinite(result.duration) && result.duration > 0
    end

    noisy_parameters = merge(p, (local_visibility=0.5, mean_photons=0.2))
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
                set_close_to!(dashboard.sliders[end], 0.08)
            elseif length(results) == 2
                dashboard.running[] = false
            end
        end
        dashboard.running[] = true
        @test timedwait(() -> length(dashboard.history[]) == 2 || istaskdone(dashboard.task), 180) == :ok
        @test length(dashboard.history[]) == 2
        sleep(0.1)
        @test length(dashboard.history[]) == 2 # paused, no second coordinator
        dashboard.running[] = true
        @test timedwait(() -> istaskdone(dashboard.task), 180) == :ok
        wait(dashboard.task) # propagate any simulation or rendering failure
        @test length(dashboard.history[]) == 3
        @test dashboard.history[][1].parameters.mean_photons == default_source_parameters.mean_photons
        @test all(r -> r.parameters.mean_photons ≈ 0.08, dashboard.history[][2:3])
        dashboard.clear.clicks[] += 1
        @test isempty(dashboard.history[])
    finally
        close(dashboard.screen)
        wait(dashboard.task)
    end
end
