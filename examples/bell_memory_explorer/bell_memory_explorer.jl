using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

isdefined(@__MODULE__, :bell_memory_trace) || include("setup.jl")

@info "all library imports are complete"

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}")

function make_bell_memory_figure()
    fig = Figure(size = (900, 620))

    controls = fig[1, 1] = GridLayout(tellwidth = false)
    plot_area = fig[2, 1] = GridLayout()

    defaults = (F = 0.95, T2 = 100.0, tmax = 300.0, samples = 121)
    trace = bell_memory_trace(; defaults...)

    time_obs = Observable(trace.time)
    xx_obs = Observable(trace.xx)
    yy_obs = Observable(trace.yy)
    zz_obs = Observable(trace.zz)
    fid_obs = Observable(trace.fidelity)

    sg = SliderGrid(
        controls,
        (label = "initial Bell-pair fidelity", range = 0.25:0.01:1.0, format = "{:.2f}", startvalue = defaults.F),
        (label = "T2 memory lifetime", range = 5.0:5.0:500.0, format = "{:.1f}", startvalue = defaults.T2),
        (label = "time horizon", range = 10.0:10.0:1000.0, format = "{:.1f}", startvalue = defaults.tmax),
        width = 650,
    )

    ax_stab = Axis(plot_area[1, 1], xlabel = "storage time", ylabel = "stabilizer expectation")
    ax_fid = Axis(plot_area[2, 1], xlabel = "storage time", ylabel = "Bell fidelity estimate")

    colors = Makie.wong_colors()
    lines!(ax_stab, time_obs, xx_obs; label = "XX", color = colors[1])
    lines!(ax_stab, time_obs, yy_obs; label = "YY", color = colors[2])
    lines!(ax_stab, time_obs, zz_obs; label = "ZZ", color = colors[3])
    axislegend(ax_stab; position = :rt)
    lines!(ax_fid, time_obs, fid_obs; color = colors[4])

    function refresh!()
        next_trace = bell_memory_trace(
            F = sg.sliders[1].value[],
            T2 = sg.sliders[2].value[],
            tmax = sg.sliders[3].value[],
            samples = defaults.samples,
        )
        time_obs[] = next_trace.time
        xx_obs[] = next_trace.xx
        yy_obs[] = next_trace.yy
        zz_obs[] = next_trace.zz
        fid_obs[] = next_trace.fidelity
        autolimits!(ax_stab)
        autolimits!(ax_fid)
    end

    for slider in sg.sliders
        on(slider.value) do _
            refresh!()
        end
    end

    fig
end

landing = Bonito.App(; title = "Bell Memory Explorer") do
    fig = make_bell_memory_figure()
    content = md"""
    # Bell Memory Explorer

    Use the sliders to inspect how a stored Bell pair evolves under T2 dephasing.
    The stabilizer traces show which correlations are protected by the memory
    model and which decay with storage time.

    $(fig.scene)

    The `XX`, `YY`, and `ZZ` curves are sampled directly from a QuantumSavory
    register initialized with `DepolarizedBellPair`. The fidelity estimate uses
    the Bell-state stabilizer identity `(1 + XX - YY + ZZ) / 4`.

    [See and modify the code for this app on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/bell_memory_explorer)
    """
    Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end

@info "app definition is complete"

isdefined(Main, :server) && close(server)
port = parse(Int, get(ENV, "QS_BELL_MEMORY_PORT", "8897"))
interface = get(ENV, "QS_BELL_MEMORY_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_BELL_MEMORY_PROXY", "")
server = Bonito.Server(interface, port; proxy_url)
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing)

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

if abspath(PROGRAM_FILE) == @__FILE__
    wait(server)
end
