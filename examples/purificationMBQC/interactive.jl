using GLMakie

include("interactive_setup.jl")

function purification_dashboard(; max_runs=typemax(Int))
    figure = Figure(size=(1350, 850))
    Label(figure[1, 1:2], "MBQC purification · [[4,2,2]] code", fontsize=24)
    axis = Axis(figure[2, 1], xlabel="Completion time (source attempt periods; log scale)",
        ylabel="Mean output Bell fidelity in one trajectory", xscale=log10,
        yticks=([-0.1, 0, 0.5, 1], ["Rejected", "0", "0.5", "1"]))
    ylims!(axis, -0.18, 1.08)
    xlims!(axis, 1, 10)

    history = Observable(NamedTuple[])
    history_generation = Ref(0)
    accepted = lift(rs -> filter(r -> r.accepted, rs), history)
    rejected = lift(rs -> filter(r -> !r.accepted, rs), history)
    scatter!(axis, lift(rs -> [Point2f(r.duration, r.fidelity) for r in rs], accepted),
        color=(:steelblue, 0.65), markersize=12, label="Accepted",
        inspector_label=(plot, i, position) -> trial_description(accepted[][i]))
    scatter!(axis, lift(rs -> [Point2f(r.duration, -0.1) for r in rs], rejected),
        color=(:firebrick, 0.65), marker=:xcross, markersize=12, label="Rejected",
        inspector_label=(plot, i, position) -> trial_description(rejected[][i]))
    hlines!(axis, [0.5], color=(:gray, 0.5), linestyle=:dash, inspectable=false)
    axislegend(axis, position=:lb)
    DataInspector(figure)

    controls = figure[2, 2] = GridLayout()
    Label(controls[1, 1], "Local links · Barrett–Kok", fontsize=19)
    p = default_source_parameters
    local_grid = SliderGrid(controls[2, 1],
        (label="Transmission A", range=0.1:0.01:1, startvalue=p.local_transmission_a),
        (label="Transmission B", range=0.1:0.01:1, startvalue=p.local_transmission_b),
        (label="Detection efficiency", range=0.1:0.01:1, startvalue=p.local_detection),
        (label="Dark-count probability", range=0:0.0001:0.01,
            startvalue=p.local_dark_counts, format="{:.4f}"),
        (label="Mode overlap |V| (real)", range=0:0.01:1, startvalue=p.local_visibility))
    Label(controls[3, 1], "Long-range links · Genqo cascaded source", fontsize=19)
    long_grid = SliderGrid(controls[4, 1],
        (label="BSM transmission", range=0.1:0.01:1, startvalue=p.long_bsm),
        (label="Detection efficiency", range=0.1:0.01:1, startvalue=p.long_detection),
        (label="Outcoupling transmission", range=0.1:0.01:1, startvalue=p.long_transmission),
        (label="Mean photons per mode N", range=0.001:0.001:0.2,
            startvalue=p.mean_photons, format="{:.3f}"))
    sliders = vcat(local_grid.sliders, long_grid.sliders)
    snapshot() = NamedTuple{keys(default_source_parameters)}(Tuple(s.value[] for s in sliders))

    running = Observable(true)
    buttons = figure[3, 1:2] = GridLayout(tellwidth=false)
    pause = Button(buttons[1, 1], label=lift(r -> r ? "Pause after this run" : "Resume", running))
    clear = Button(buttons[1, 2], label="Clear history")
    on(pause.clicks) do _
        running[] = !running[]
    end
    on(clear.clicks) do _
        history_generation[] += 1
        history[] = NamedTuple[]
    end
    statistics = lift(history) do results
        isempty(results) && return "Waiting for the first run (initial compilation can take a minute)."
        successes = filter(r -> r.accepted, results)
        f = isempty(successes) ? "—" : string(round(mean(r.fidelity for r in successes), digits=3))
        acceptance = round(100 * length(successes) / length(results), digits=1)
        yield_per_period = 2 * length(successes) / sum(r.duration for r in results)
        "Visible window: $(length(results))/100 runs · accepted $acceptance% · " *
        "mean accepted fidelity $f\nRetained pairs / attempt period: $(round(yield_per_period, sigdigits=3))"
    end
    Label(figure[4, 1:2], statistics)
    status = Observable("Preparing the first source states…")
    Label(figure[5, 1:2], status)
    Label(figure[6, 1:2],
        "One point = one complete stochastic protocol attempt. Hover for its source settings.\n" *
        "Sliders take effect on the next run. Statistics mix settings until you clear history.\n" *
        "Ideal gates and memories; equal source attempt periods; single-mode Genqo heralding weight.\n" *
        "Fidelity is sampled (0, ½ or 1): its accepted mean estimates the conditional output fidelity.",
        fontsize=14)
    colsize!(figure.layout, 1, Relative(0.55))
    screen = display(figure)

    # One coordinator owns Makie updates. Only the simulation and source model
    # evaluation run on a worker. Pause/resume never creates overlapping runs.
    task = errormonitor(@async begin
        previous_parameters = nothing
        sources = nothing
        completed = 0
        try
            while isopen(screen) && completed < max_runs
                if !running[]
                    sleep(0.05)
                    continue
                end
                parameters = snapshot() # immutable snapshot, before launching the worker
                generation = history_generation[]
                result, sources = fetch(Threads.@spawn begin
                    current_sources = parameters == previous_parameters ? sources : purification_sources(parameters)
                    purification_trial(parameters, current_sources), current_sources
                end)
                isopen(screen) || break
                previous_parameters = parameters
                completed += 1
                generation == history_generation[] || continue # cleared during this run
                retain_trial!(history[], result)
                notify(history)
                times = [r.duration for r in history[]]
                xlims!(axis, 0.8minimum(times), 1.25maximum(times))
                status[] = "Run $completed · input fidelity $(round(result.input_fidelity, digits=3)) · " *
                    "local fidelity $(round(result.local_fidelity, digits=3)) · " *
                    "heralding: local $(round(result.local_probability, sigdigits=3)), " *
                    "long-range $(round(result.long_probability, sigdigits=3))"
                sleep(0.02) # let the window process input, even for very fast trials
            end
        catch error
            status[] = "Simulation stopped: $(sprint(showerror, error))"
            rethrow()
        finally
            running[] = false
        end
    end)
    (; figure, screen, task, history, running, sliders, snapshot, clear, status)
end

function trial_description(result)
    outcome = result.accepted ? "Output fidelity: $(result.fidelity)" : "Rejected (no output pair)"
    settings = join(["$name = $value" for (name, value) in pairs(result.parameters)], "\n")
    "$outcome\nCompletion: $(result.duration) attempt periods\n$settings"
end

if abspath(PROGRAM_FILE) == @__FILE__
    test_run = get(ENV, "QS_TESTRUN", "false") == "true"
    dashboard = purification_dashboard(; max_runs=test_run ? 3 : typemax(Int))
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
