using Makie

include("setup.jl")

function path_edges(path)
    length(path) < 2 && return Set{Tuple{Int, Int}}()
    return Set(edge_tuple(Edge(path[i], path[i + 1])) for i in 1:(length(path) - 1))
end

function draw_lattice_trial!(ax, trial)
    empty!(ax)
    coordinates = lattice_coordinates(trial.n)
    open_edge_set = Set(trial.open_edges)
    selected_edge_set = path_edges(trial.selected_path)

    for edge in edges(trial.graph)
        u, v = edge_tuple(edge)
        x = [coordinates[u][1], coordinates[v][1]]
        y = [coordinates[u][2], coordinates[v][2]]
        linewidth = (u, v) in selected_edge_set ? 7 : ((u, v) in open_edge_set ? 4 : 1)
        color = (u, v) in selected_edge_set ? :crimson :
                ((u, v) in open_edge_set ? :seagreen : (:gray70, 0.45))
        lines!(ax, x, y; color, linewidth)
    end

    xs = [coordinates[v][1] for v in vertices(trial.graph)]
    ys = [coordinates[v][2] for v in vertices(trial.graph)]
    node_colors = fill(:white, nv(trial.graph))
    node_colors[trial.source] = :dodgerblue
    node_colors[trial.target] = :gold
    scatter!(ax, xs, ys; color=node_colors, strokecolor=:black, strokewidth=1.5, markersize=20)
    text!(ax, coordinates[trial.source]...; text="Alice", align=(:right, :bottom), offset=(-8, 8), fontsize=16)
    text!(ax, coordinates[trial.target]...; text="Bob", align=(:left, :top), offset=(8, -8), fontsize=16)

    ax.aspect = DataAspect()
    ax.title = trial.connected ?
        "Connected path with $(trial.path_hops) hops" :
        "No heralded Alice-Bob path in this round"
    hidedecorations!(ax)
    hidespines!(ax)
    autolimits!(ax)
    return ax
end

function histogram_counts(trials, max_hops)
    counts = zeros(Int, max_hops)
    for trial in trials
        trial.connected || continue
        1 <= trial.path_hops <= max_hops && (counts[trial.path_hops] += 1)
    end
    return counts
end

function build_dashboard(; seed=3, samples=200)
    fig = Figure(size=(1350, 820))
    ax_lattice = Axis(fig[1:3, 1])
    ax_hist = Axis(fig[1, 2], xlabel="successful path hops", ylabel="trials")
    ax_probability = Axis(fig[2, 2], xlabel="link success probability", ylabel="connection probability")
    ax_fidelity = Axis(fig[3, 2], xlabel="link success probability", ylabel="mean delivered fidelity")
    controls = fig[4, 1:2] = GridLayout(tellwidth=false)

    n_slider = Slider(controls[1, 2], range=3:8, startvalue=5)
    p_slider = Slider(controls[2, 2], range=0.05:0.05:0.95, startvalue=0.55)
    f_slider = Slider(controls[3, 2], range=0.80:0.01:0.99, startvalue=0.97)
    swap_slider = Slider(controls[4, 2], range=0.90:0.005:1.0, startvalue=0.99)
    seed_button = Button(controls[5, 2], label="new heralding round")
    current_seed = Observable(seed)

    Label(controls[1, 1], "lattice size")
    Label(controls[2, 1], "link success")
    Label(controls[3, 1], "elementary fidelity")
    Label(controls[4, 1], "swap visibility")

    summary_text = Observable("")
    Label(controls[1:5, 3], summary_text; tellwidth=false, halign=:left)

    function refresh!()
        n = Int(round(n_slider.value[]))
        link_success = Float64(p_slider.value[])
        link_fidelity = Float64(f_slider.value[])
        swap_visibility = Float64(swap_slider.value[])
        trial = run_percolation_trial(; n, link_success, link_fidelity, swap_visibility, seed=current_seed[])
        ensemble = run_percolation_ensemble(; n, link_success, link_fidelity, swap_visibility, samples, seed=10_000 + current_seed[])

        draw_lattice_trial!(ax_lattice, trial)

        empty!(ax_hist)
        max_hops = 2 * (n - 1)
        counts = histogram_counts(ensemble.trials, max_hops)
        barplot!(ax_hist, 1:max_hops, counts; color=:seagreen)
        ax_hist.xlabel = "successful path hops"
        ax_hist.ylabel = "trials"

        ps = collect(0.05:0.05:0.95)
        summaries = [run_percolation_ensemble(;
            n,
            link_success=p,
            link_fidelity,
            swap_visibility,
            samples=max(40, samples ÷ 4),
            seed=20_000 + current_seed[] + round(Int, 100p),
        ) for p in ps]

        empty!(ax_probability)
        lines!(ax_probability, ps, [s.success_rate for s in summaries]; color=:dodgerblue, linewidth=3)
        scatter!(ax_probability, [link_success], [ensemble.success_rate]; color=:crimson, markersize=14)
        ylims!(ax_probability, -0.03, 1.03)

        empty!(ax_fidelity)
        lines!(ax_fidelity, ps, [s.mean_estimated_fidelity for s in summaries]; color=:purple, linewidth=3)
        if ensemble.connected_count > 0
            scatter!(ax_fidelity, [link_success], [ensemble.mean_estimated_fidelity]; color=:crimson, markersize=14)
        end
        ylims!(ax_fidelity, 0.65, 1.0)

        summary_text[] = if trial.connected
            "This round connected Alice and Bob.\n" *
            "Open links: $(length(trial.open_edges)) / $(ne(trial.graph))\n" *
            "Path hops: $(trial.path_hops)\n" *
            "Estimated fidelity: $(round(trial.estimated_fidelity; digits=4))\n" *
            "Ensemble connection rate: $(round(100 * ensemble.success_rate; digits=1))%"
        else
            "This round did not connect Alice and Bob.\n" *
            "Open links: $(length(trial.open_edges)) / $(ne(trial.graph))\n" *
            "Ensemble connection rate: $(round(100 * ensemble.success_rate; digits=1))%\n" *
            "Increase link success or try a new round."
        end

        return nothing
    end

    on(seed_button.clicks) do _
        current_seed[] += 1
        refresh!()
    end
    on(n_slider.value) do _; refresh!() end
    on(p_slider.value) do _; refresh!() end
    on(f_slider.value) do _; refresh!() end
    on(swap_slider.value) do _; refresh!() end

    refresh!()
    return fig
end
