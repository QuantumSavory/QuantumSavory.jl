using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW

using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

@info "all library imports are complete"

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}") # TODO remove after fix of bug in JSServe https://github.com/SimonDanisch/JSServe.jl/issues/178

#

const permitted_queries = Dict(
    "MultiplexedCascadedBellPairW" => MultiplexedCascadedBellPairW,
    "BarrettKokBellPairW" => BarrettKokBellPairW,
    "GenqoUnheraldedSPDCBellPairW" => GenqoUnheraldedSPDCBellPairW,
    "GenqoMultiplexedCascadedBellPairW" => GenqoMultiplexedCascadedBellPairW,
)

landing = Bonito.App(; title="State Explorer") do
    content = md"""
    Please select one of the following:

    - [Barrett-Kok Bell Pair](./vis/BarrettKokBellPairW)
    - [ZALM Bell Pair](./vis/MultiplexedCascadedBellPairW)
    - [Genqo Unheralded SPDC Bell Pair](./vis/GenqoUnheraldedSPDCBellPairW)
    - [Genqo Multiplexed Cascaded Bell Pair](./vis/GenqoMultiplexedCascadedBellPairW)
    """
    Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end

vis = Bonito.App(; title="State Explorer") do request::Bonito.HTTP.Request
    statekey = string(split(request.target, "/")[end])
    state = get(permitted_queries, statekey, nothing)
    if isnothing(state)
        content = md"""
            Unrecognized state...
        """
    else
        fig = stateexplorer(state)
        link = "https://qs.quantumsavory.org/dev/API_StatesZoo/#QuantumSavory.StatesZoo.$(statekey)"
        doc = Markdown.Paragraph(Markdown.Link("See the documentation for implemented states.",link))
        content = md"""
        # $(statekey)

        $(fig.scene)

        The Bell pair is shown in the bar plots (both in the Z and in the Bell bases).

        The sliders let you modify various state parameters. For ease of exploration, figures of merit for modifying one parameter while keeping all others constant are also plotted. The first row corresponds to fidelity (with respect to perfect state) and the second row is the trace of the state (i.e. the probability of successful generation).

        $doc

        [See and modify the code for this app on github.](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/state_explorer)
        """
    end
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
Bonito.route!(server, r"/vis/.*" => vis);

##

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

wait(server)
