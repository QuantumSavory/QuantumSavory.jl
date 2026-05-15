using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown
using Printf
using Gabs: wigner

include("setup.jl")

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}")
const WIGNER_AXIS = collect(range(-3.5, 3.5, length = 90))

function wigner_grid(state; axis = WIGNER_AXIS)
    return [wigner(state, [q, p]) for q in axis, p in axis]
end

function summarize_result(result)
    return @sprintf(
        "fidelity = %.6f    max |Δmean| = %.3e    max |Δcovariance| = %.3e",
        result.fidelity,
        result.mean_error,
        result.covariance_error,
    )
end

function run_from_controls(amplitude, phase, squeeze)
    return run_assisted_teleportation(;
        input_state = coherent_input_state(amplitude, phase),
        squeezes = fill(squeeze, 3),
    )
end

function add_controls(fig)
    sg = SliderGrid(
        fig,
        (label = "input amplitude", range = 0.0:0.05:1.5, format = "{:.2f}", startvalue = abs(DEFAULT_INPUT_AMPLITUDE)),
        (label = "input phase", range = -pi:pi/40:pi, format = "{:.2f}", startvalue = angle(DEFAULT_INPUT_AMPLITUDE)),
        (label = "resource squeezing", range = 1.0:0.25:7.0, format = "{:.2f}", startvalue = RESOURCE_SQUEEZE),
        width = 700,
    )
    return sg.sliders
end

@info "assisted CV teleportation app definition is loading"

landing = Bonito.App() do
    fig = Figure(size = (1200, 820))

    controls = fig[1, 1:3] = GridLayout(tellheight = false)
    sliders = add_controls(controls[1, 1])
    run_button = Button(controls[1, 2], label = "Run")

    initial_result = run_from_controls(
        sliders[1].value[],
        sliders[2].value[],
        sliders[3].value[],
    )
    initial_wigner = Observable(wigner_grid(initial_result.initial_state))
    teleported_wigner = Observable(wigner_grid(initial_result.teleported_state))
    difference_wigner = Observable(teleported_wigner[] .- initial_wigner[])

    ax_in = Axis(fig[2, 1], xlabel = "x", ylabel = "p", title = "input Wigner function")
    ax_out = Axis(fig[2, 2], xlabel = "x", ylabel = "p", title = "Bob output Wigner function")
    ax_diff = Axis(fig[2, 3], xlabel = "x", ylabel = "p", title = "output - input")

    heatmap!(ax_in, WIGNER_AXIS, WIGNER_AXIS, initial_wigner)
    heatmap!(ax_out, WIGNER_AXIS, WIGNER_AXIS, teleported_wigner)
    heatmap!(ax_diff, WIGNER_AXIS, WIGNER_AXIS, difference_wigner; colormap = :balance)

    metric_label = Label(fig[3, 1:3], summarize_result(initial_result), tellwidth = false)

    on(run_button.clicks) do _
        result = run_from_controls(
            sliders[1].value[],
            sliders[2].value[],
            sliders[3].value[],
        )
        initial_wigner[] = wigner_grid(result.initial_state)
        teleported_wigner[] = wigner_grid(result.teleported_state)
        difference_wigner[] = teleported_wigner[] .- initial_wigner[]
        metric_label.text[] = summarize_result(result)
        autolimits!.((ax_in, ax_out, ax_diff))
    end

    content = md"""
    Pick an input coherent state and the shared-resource squeezing, then rerun
    the assisted continuous-variable teleportation protocol.

    $(fig.scene)

    # Assisted continuous-variable teleportation

    Alice starts with an unknown coherent input state. Alice, Bob, and Charlie
    share a three-mode Gaussian resource. Alice performs a Bell-like homodyne
    measurement, Charlie contributes the assisting homodyne result, and Bob uses
    both classical messages to displace his mode.

    The left and middle heatmaps compare the input and Bob's teleported output
    through their Wigner functions. The right heatmap shows the residual
    difference. Increasing the resource squeezing drives the fidelity closer to
    one.

    [See and modify the code for this simulation on GitHub.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/assisted_cvteleportation)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end;

@info "assisted CV teleportation app definition is complete"

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_ASSISTED_CV_TELEPORTATION_PORT", "8896"))
interface = get(ENV, "QS_ASSISTED_CV_TELEPORTATION_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_ASSISTED_CV_TELEPORTATION_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

if abspath(PROGRAM_FILE) == @__FILE__
    wait(server)
end
