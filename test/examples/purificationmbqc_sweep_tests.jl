using Test
using Random

include("../../examples/purificationMBQC/sweep.jl")

@testset "MBQC sweep statistics and scales" begin
    Random.seed!(0x53574545)
    p = merge(default_source_parameters, (local_visibility=0.5, mean_photons=0.2))
    sources = purification_sources(p)
    results = [purification_trial(p, sources) for _ in 1:40]
    summary = summarize_trials(results)
    @test 0 < summary.acceptance < 1
    @test 0 <= summary.fidelity <= 1
    @test summary.pair_rate ≈ k * summary.acceptance / summary.duration
    @test summary.input_fidelity == sources.long_source.fidelity
    @test summary.local_fidelity == sources.local_source.fidelity

    rejected = summarize_trials(filter(r -> !r.accepted, results))
    @test rejected.acceptance == rejected.pair_rate == 0
    @test isnan(rejected.fidelity)
    @test isfinite(rejected.duration) && rejected.duration > 0
    @test aggregate_scale([NaN, 0.001, 1.0]) === log10
    for values in (Float64[], [NaN], [0.5, 0.6], [2.0, 2.0], [0.0, 0.001, 1.0], [-1.0, 1000.0])
        @test aggregate_scale(values) === identity
    end
end

@testset "MBQC sweep: two complete 1000-trial settings" begin
    dashboard = purification_sweep_dashboard(sweep_points=2, max_sweeps=1)
    batches = Vector{NamedTuple}[]
    try
        dashboard.running[] = false
        # Perfect conditional sources give exact self-consistency checks despite
        # their stochastic generation times and the different photon numbers.
        for (index, value) in ((4, 0.0), (5, 1.0), (6, 1.0), (7, 1.0), (8, 1.0))
            set_close_to!(dashboard.sliders[index], value)
        end
        fixed = dashboard.snapshot()
        on(dashboard.history) do results
            length(results) == 1000 && push!(batches, copy(results))
        end
        on(dashboard.aggregates) do summaries
            isempty(summaries) && return
            @test length(dashboard.history[]) == 1000
        end
        dashboard.running[] = true
        @test timedwait(() -> istaskdone(dashboard.task), 240) == :ok
        wait(dashboard.task)
        @test dashboard.finished[]
        @test !dashboard.running[]
        @test isempty(dashboard.history[])
        @test length(batches) == length(dashboard.aggregates[]) == 2
        @test [r.value for r in dashboard.aggregates[]] ≈ [0.001, 0.2]
        for (batch, summary) in zip(batches, dashboard.aggregates[])
            @test length(batch) == summary.samples == summary.accepted == 1000
            @test summary.acceptance == 1
            @test summary.fidelity ≈ 1
            @test summary.input_fidelity ≈ 1
            @test summary.local_fidelity ≈ 1
            @test isfinite(summary.duration) && summary.duration > 0
            @test summary.pair_rate ≈ k / summary.duration
            @test all(r -> r.parameters == summary.parameters, batch)
            @test summary.parameters == merge(fixed, (mean_photons=summary.value,))
        end
        @test count(r -> r.checked[], dashboard.radios) == 1
        @test dashboard.radios[9].checked[] # mean photons remains the default
        # The real source's generation rate spans orders of magnitude. Exercise
        # the actual axes, then restart to clear them safely back to linear.
        @test dashboard.axes[3].yscale[] === log10
        @test dashboard.axes[4].yscale[] === log10
        dashboard.restart.clicks[] += 1
        @test isempty(dashboard.aggregates[])
        @test all(a -> a.yscale[] === identity, dashboard.axes)
    finally
        close(dashboard.screen)
        wait(dashboard.task)
    end
end

@testset "MBQC sweep controls discard partial settings" begin
    dashboard = purification_sweep_dashboard(samples_per_point=30, sweep_points=2, max_sweeps=1)
    changed = Ref(false)
    paused = Ref(false)
    try
        dashboard.running[] = false
        sleep(0.05)
        @test isempty(dashboard.history[])
        on(dashboard.status) do status
            if !changed[] && length(dashboard.history[]) == 10 && startswith(status, "Running")
                changed[] = true
                @test isempty(dashboard.aggregates[])
                # The coordinator launches its worker and yields at fetch; this
                # UI task then changes settings while that worker is in flight.
                @async begin
                    @test length(dashboard.history[]) == 10 # pending results are not published
                    set_close_to!(dashboard.sliders[8], 0.7)
                    dashboard.radios[10].onchange[](dashboard.radios[10].checked[])
                end
            end
        end
        on(dashboard.history) do results
            isempty(results) && return
            if changed[] && dashboard.selected[] == 10 && !paused[]
                paused[] = true
                dashboard.running[] = false
            end
        end
        dashboard.running[] = true
        @test timedwait(() -> paused[] || istaskdone(dashboard.task), 180) == :ok
        @test paused[]
        @test length(dashboard.history[]) == 10
        sleep(0.1)
        @test length(dashboard.history[]) == 10
        @test isempty(dashboard.aggregates[])
        @test dashboard.selected[] == 10
        @test count(r -> r.checked[], dashboard.radios) == 1
        @test dashboard.radios[10].checked[]
        dashboard.pause.clicks[] += 1
        @test timedwait(() -> istaskdone(dashboard.task), 180) == :ok
        wait(dashboard.task)
        @test [r.value for r in dashboard.aggregates[]] == [0.0, 1.0]
        @test all(r -> r.samples == 30 && r.parameters.long_transmission ≈ 0.7, dashboard.aggregates[])
        @test [r.parameters.spin_capture_noise for r in dashboard.aggregates[]] == [0.0, 1.0]
        @test last(dashboard.aggregates[]).input_fidelity ≈ 0.25
        @test isempty(dashboard.history[])
    finally
        close(dashboard.screen)
        wait(dashboard.task)
    end
end
