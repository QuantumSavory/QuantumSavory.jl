using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

include("setup.jl")

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}")

function sweep_cutoffs(; retention_center = 5.0, success_prob = 0.15, T2 = 40.0, duration = 40.0)
    retention_values = clamp.(
        retention_center .* [0.4, 0.7, 1.0, 1.5, 2.2],
        0.5,
        30.0,
    )
    [
        run_cutoff_point(;
            retention_time = retention,
            agelimit_buffer = min(0.5, retention / 4),
            success_prob,
            T2,
            duration,
            random_seed = 200 + i,
        )
        for (i, retention) in enumerate(retention_values)
    ]
end

function build_figure(results)
    fig = Figure(size = (900, 560))

    retentions = Observable([row.retention_time for row in results])
    delivered = Observable([row.delivered for row in results])
    mean_zz = Observable([isnan(row.mean_zz) ? 0.0 : row.mean_zz for row in results])
    mean_xx = Observable([isnan(row.mean_xx) ? 0.0 : row.mean_xx for row in results])

    ax_delivered = Axis(fig[1, 1], xlabel = "retention time", ylabel = "delivered pairs")
    barplot!(ax_delivered, retentions, delivered; color = Makie.wong_colors()[1])

    ax_fidelity = Axis(fig[1, 2], xlabel = "retention time", ylabel = "mean stabilizer")
    lines!(ax_fidelity, retentions, mean_zz; label = "ZZ", color = Makie.wong_colors()[2])
    scatter!(ax_fidelity, retentions, mean_zz; color = Makie.wong_colors()[2])
    lines!(ax_fidelity, retentions, mean_xx; label = "XX", color = Makie.wong_colors()[3])
    scatter!(ax_fidelity, retentions, mean_xx; color = Makie.wong_colors()[3])
    axislegend(ax_fidelity, position = :lb)

    fig, (; retentions, delivered, mean_zz, mean_xx), (; ax_delivered, ax_fidelity)
end

function update_figure!(observables, axes, results)
    observables.retentions[] = [row.retention_time for row in results]
    observables.delivered[] = [row.delivered for row in results]
    observables.mean_zz[] = [isnan(row.mean_zz) ? 0.0 : row.mean_zz for row in results]
    observables.mean_xx[] = [isnan(row.mean_xx) ? 0.0 : row.mean_xx for row in results]
    autolimits!(axes.ax_delivered)
    autolimits!(axes.ax_fidelity)
end

landing = Bonito.App() do
    settings = Observable((retention_center = 5.0, success_prob = 0.15, T2 = 40.0, duration = 40.0))
    results = sweep_cutoffs(; settings[]...)
    fig, observables, axes = build_figure(results)

    controls = SliderGrid(
        fig[2, 1:2],
        (label = "center retention time", range = 1.0:0.5:12.0, format = "{:.1f}", startvalue = settings[].retention_center),
        (label = "link success probability", range = 0.02:0.01:0.5, format = "{:.2f}", startvalue = settings[].success_prob),
        (label = "T2 memory time", range = 5.0:5.0:120.0, format = "{:.1f}", startvalue = settings[].T2),
        (label = "simulation duration", range = 10.0:5.0:120.0, format = "{:.1f}", startvalue = settings[].duration),
        width = 820,
    )

    names = (:retention_center, :success_prob, :T2, :duration)
    for (name, slider) in zip(names, controls.sliders)
        on(slider.value) do value
            current = settings[]
            settings[] = merge(current, NamedTuple{(name,)}((Float64(value),)))
            update_figure!(observables, axes, sweep_cutoffs(; settings[]...))
        end
    end

    content = md"""
    # Memory cutoff tradeoff

    This example sweeps a small repeater chain over several memory retention
    times. Short retention keeps stale memories from being swapped, while long
    retention can increase throughput at the cost of older qubits.

    $(fig.scene)

    The simulation uses `EntanglerProt`, `SwapperProt`, `EntanglementTracker`,
    `CutoffProt`, and `EntanglementConsumer`.

    [See and modify the code for this simulation on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/memorycutoff)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_MEMORYCUTOFF_PORT", "8896"))
interface = get(ENV, "QS_MEMORYCUTOFF_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_MEMORYCUTOFF_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

if abspath(PROGRAM_FILE) == @__FILE__
    wait(server)
end
