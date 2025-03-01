using QuantumSavory.StatesZoo

using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

@info "all library imports are complete"

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}") # TODO remove after fix of bug in JSServe https://github.com/SimonDanisch/JSServe.jl/issues/178

#

landing = Bonito.App() do
    fig = Figure(size=(800,500))
    stateexplorer!(fig, BarrettKokBellPairW)

    content = md"""
    # The Barrett-Kok Bell Pair

    ### As parameterized in "Entangling Quantum Memories via Heralded Photonic Bell Measurement"

    $(fig.scene)

    The normalized Barret-Kok Bell pair (after two successful rounds of the Barrett-Kok style attempts are done) is shown in the bar plots (both in the Z and in the Bell bases).
    This Bell pair creation protocol is also referred to as a Bell pair heralded through a "dual rail photonic qubit based swap".

    The sliders let you modify various state parameters. For ease of exploration, figures of merit for modifying one parameter while keeping all others constant are also plotted. The first row corresponds to fidelity (with respect to perfect state) and the second row is the trace of the state (i.e. the probability of successful generation).

    [See the documentation for `BarrettKokBellPairW`](http://qs.quantumsavory.org/dev/API_StatesZoo/#QuantumSavory.StatesZoo.BarrettKokBellPairW)

    [See and modify the code for this app on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/state_explorer.jl)
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end

@info "app definition is complete"

#
# Serve the Makie app

isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_SIMPLESWITCH_PORT", "8888"))
interface = get(ENV, "QS_SIMPLESWITCH_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_SIMPLESWITCH_PROXY", "")
server = Bonito.Server(interface, port; proxy_url);
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing);

##

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

wait(server)
