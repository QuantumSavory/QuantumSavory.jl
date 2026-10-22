include("interactive_controls.jl")

function purification_dashboard(; max_runs=typemax(Int))
    figure = Figure(size=(1350, 850))
    Label(figure[1, 1:2], "MBQC purification · [[4,2,2]] code", fontsize=24)
    history = Observable(NamedTuple[])
    history_generation = Ref(0)
    axis = trajectory_axis(figure[2, 1], history)
    DataInspector(figure)

    controls = figure[2, 2] = GridLayout()
    (; sliders, snapshot, hadamard_toggle) = source_controls(controls)

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
        "Controls take effect on the next run. Statistics mix settings until you clear history.\n" *
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
    (; figure, screen, task, history, running, sliders, snapshot, hadamard_toggle, clear, status)
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
