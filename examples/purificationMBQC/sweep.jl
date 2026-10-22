include("interactive_controls.jl")

function summarize_trials(results)
    successes = filter(r -> r.accepted, results)
    total_time = sum(r.duration for r in results)
    first_result = first(results)
    (; parameters=first_result.parameters, samples=length(results), accepted=length(successes),
        acceptance=length(successes) / length(results),
        fidelity=isempty(successes) ? NaN : mean(r.fidelity for r in successes),
        duration=total_time / length(results), pair_rate=k * length(successes) / total_time,
        input_fidelity=first_result.input_fidelity, local_fidelity=first_result.local_fidelity)
end

# Missing fidelities remain gaps. Zero rates remain visible on a linear axis.
function aggregate_scale(values)
    finite = filter(isfinite, values)
    !isempty(finite) && minimum(finite) > 0 && maximum(finite) / minimum(finite) >= 100 ? log10 : identity
end

const sweep_metrics = (
    (fields=(:fidelity, :input_fidelity, :local_fidelity), label="Bell fidelity"),
    (fields=(:acceptance,), label="Acceptance probability"),
    (fields=(:duration,), label="Mean completion time (periods)"),
    (fields=(:pair_rate,), label="Retained pairs / period"),
)

function update_aggregates!(aggregates, axes, results)
    # Reset before publishing data: a previous log axis cannot accept new zeros.
    for axis in axes
        axis.yscale[] = identity
    end
    aggregates[] = results
    for (axis, metric) in zip(axes, sweep_metrics)
        values = [getproperty(r, field) for r in results for field in metric.fields]
        scale = aggregate_scale(values)
        finite = filter(isfinite, values)
        low, high = isempty(finite) ? (0.0, 1.0) : extrema(finite)
        padding = max(0.05 * (high - low), 0.01 * abs(high), 1e-12)
        ylims!(axis, scale === log10 ? (0.8low, 1.25high) : (low - padding, high + padding))
        axis.yscale[] = scale
    end
    # Keep equal gutters as tick widths change between linear and log scales.
    tickspace = maximum(tight_yticklabel_spacing!, axes)
    for axis in axes
        axis.yticklabelspace[] = tickspace
    end
end

function purification_sweep_dashboard(; samples_per_point=1000, sweep_points=11,
        max_sweeps=typemax(Int))
    samples_per_point > 0 || throw(ArgumentError("samples_per_point must be positive"))
    sweep_points >= 2 || throw(ArgumentError("sweep_points must be at least two"))
    figure = Figure(size=(1800, 1200), fontsize=15)
    Label(figure[1, 1:3], "MBQC purification · sweep one source parameter", fontsize=24)
    left = figure[2, 1] = GridLayout()
    history = Observable(NamedTuple[])
    finished = Observable(false)
    axis = trajectory_axis(left[1, 1], history)
    axis.title[] = "Current setting · $samples_per_point trials"
    statistics = lift(history, finished) do results, done
        done && isempty(results) && return "Sweep complete.\nThe aggregate curves remain visible."
        isempty(results) && return "0 / $samples_per_point trials at this setting"
        s = summarize_trials(results)
        f = isnan(s.fidelity) ? "—" : string(round(s.fidelity, digits=3))
        "$(s.samples) / $samples_per_point trials · accepted $(round(100s.acceptance, digits=1))%\n" *
        "Mean accepted fidelity $f\nRetained pairs / period: $(round(s.pair_rate, sigdigits=3))"
    end
    Label(left[2, 1], statistics, tellwidth=false)
    Label(left[3, 1], "One point = one complete protocol attempt.\nHover for the exact source settings.\nThe batch clears before each new setting.", fontsize=14, tellwidth=false)

    controls = figure[2, 2] = GridLayout(tellheight=false)
    selected = Observable(length(default_source_parameters))
    (; sliders, snapshot, radios) = source_controls(controls; selected)
    Label(controls[5, 1], "Select a circle to sweep that parameter.\n$sweep_points values across its full slider range.\nOther settings stay fixed throughout the sweep.", fontsize=14)
    running = Observable(true)
    buttons = controls[6, 1] = GridLayout(tellwidth=false)
    pause = Button(buttons[1, 1], label=lift(r -> r ? "Pause" : "Resume", running))
    restart = Button(buttons[1, 2], label="Restart sweep")
    status = Observable("Preparing sources (the first run can take a minute)…")
    Label(figure[3, 1:3], status)
    Label(figure[4, 1:3],
        "Each aggregate uses $samples_per_point trials at one setting. Changing a slider or selection restarts the sweep.\n" *
        "Fidelity averages accepted trials only; rates and times include rejections. No accepted trials → fidelity gap.\n" *
        "Ideal gates and memories; equal source attempt periods; single-mode Genqo heralding weight.", fontsize=14)

    aggregate_layout = figure[2, 3] = GridLayout()
    aggregates = Observable(NamedTuple[])
    xlabel = lift(i -> source_parameter_labels[i], selected)
    axes = [Axis(aggregate_layout[i, 1]; xlabel, ylabel=m.label,
        xlabelsize=13, ylabelsize=13, xticklabelsize=12, yticklabelsize=12) for (i, m) in enumerate(sweep_metrics)]
    linkxaxes!(axes...)
    for a in axes[1:end-1]
        hidexdecorations!(a; ticks=false, grid=false, minorticks=false, minorgrid=false)
    end
    for (a, metric) in zip(axes, sweep_metrics)
        for (field, color, label) in zip(metric.fields,
                (:steelblue, :darkorange, :seagreen), ("Output | accepted", "Long-range input", "Local pair"))
            positions = lift(rs -> [Point2f(r.value, getproperty(r, field)) for r in rs], aggregates)
            scatterlines!(a, positions; color, label, markersize=7, inspectable=false)
        end
    end
    update_aggregates!(aggregates, axes, NamedTuple[])
    axislegend(axes[1], position=:lb, labelsize=11, orientation=:horizontal, nbanks=3)
    DataInspector(figure)
    colsize!(figure.layout, 1, Relative(0.32))
    colsize!(figure.layout, 2, Relative(0.34))

    generation = Ref(0)
    moving_slider = Ref(false)
    function reset_sweep!()
        generation[] += 1
        history[] = NamedTuple[]
        update_aggregates!(aggregates, axes, NamedTuple[])
        finished[] = false
        status[] = "Sweep reset; waiting for the next trials."
    end
    on(restart.clicks) do _
        reset_sweep!()
        running[] = true
    end
    on(pause.clicks) do _
        finished[] && reset_sweep!()
        running[] = !running[]
    end
    on(selected) do _
        was_finished = finished[]
        reset_sweep!()
        was_finished && (running[] = true)
    end
    for slider in sliders
        on(slider.value) do _
            moving_slider[] && return
            was_finished = finished[]
            reset_sweep!()
            was_finished && (running[] = true)
        end
    end
    screen = display(figure)

    # One coordinator updates Makie; workers run at most ten trials at a time.
    # Epoch checks discard work returned after an edit, restart, or close.
    task = errormonitor(@async begin
        active_generation = -1
        completed_sweeps = 0
        point = 1
        values = Float64[]
        fixed_parameters = snapshot()
        parameters = fixed_parameters
        parameter = keys(fixed_parameters)[selected[]]
        sources = nothing
        try
            while isopen(screen)
                if !running[]
                    sleep(0.05)
                    continue
                end
                if active_generation != generation[]
                    active_generation = generation[]
                    fixed_parameters = snapshot()
                    parameter = keys(fixed_parameters)[selected[]]
                    slider_range = sliders[selected[]].range[]
                    indices = unique(round.(Int, range(1, length(slider_range); length=sweep_points)))
                    values = collect(slider_range[indices])
                    point = 1
                    xlims!(axes[end], first(values), last(values))
                end
                if isempty(history[])
                    parameters = merge(fixed_parameters, NamedTuple{(parameter,)}((values[point],)))
                    moving_slider[] = true
                    try
                        set_close_to!(sliders[selected[]], values[point])
                    finally
                        moving_slider[] = false
                    end
                    sources = nothing
                    xlims!(axis, 1, 10)
                end
                count = min(10, samples_per_point - length(history[]))
                status[] = "Running $(source_parameter_labels[selected[]]) = $(values[point]) · " *
                    "setting $point / $(length(values)) · $(length(history[])) / $samples_per_point trials complete"
                results, sources = fetch(Threads.@spawn begin
                    current_sources = isnothing(sources) ? purification_sources(parameters) : sources
                    [purification_trial(parameters, current_sources) for _ in 1:count], current_sources
                end)
                isopen(screen) || break
                active_generation == generation[] || continue
                append!(history[], results)
                notify(history)
                # Observers can also request a restart while receiving a batch.
                active_generation == generation[] || continue
                times = [r.duration for r in history[]]
                xlims!(axis, 0.8minimum(times), 1.25maximum(times))
                status[] = "$(source_parameter_labels[selected[]]) = $(values[point]) · " *
                    "setting $point / $(length(values)) · $(length(history[])) / $samples_per_point trials"
                if length(history[]) == samples_per_point
                    summary = merge(summarize_trials(history[]), (value=values[point],))
                    update_aggregates!(aggregates, axes, [aggregates[]; summary])
                    sleep(0.1) # allow the complete batch to render before clearing
                    isopen(screen) || break
                    active_generation == generation[] || continue
                    history[] = NamedTuple[]
                    point += 1
                    if point > length(values)
                        completed_sweeps += 1
                        finished[] = true
                        running[] = false
                        status[] = "Sweep complete · $(length(values)) settings × $samples_per_point trials. Restart or change a setting to run again."
                        completed_sweeps >= max_sweeps && break
                    end
                end
                sleep(0.01) # service window input between small groups of trials
            end
        catch error
            status[] = "Simulation stopped: $(sprint(showerror, error))"
            rethrow()
        finally
            running[] = false
        end
    end)
    (; figure, screen, task, history, aggregates, axes, sliders, radios, selected,
        snapshot, running, finished, pause, restart, status)
end

if abspath(PROGRAM_FILE) == @__FILE__
    test_run = get(ENV, "QS_TESTRUN", "false") == "true"
    dashboard = test_run ? purification_sweep_dashboard(samples_per_point=5, sweep_points=2, max_sweeps=1) :
        purification_sweep_dashboard()
    if test_run
        try
            wait(dashboard.task)
        finally
            close(dashboard.screen)
        end
    else
        wait(dashboard.screen)
        wait(dashboard.task)
    end
end
