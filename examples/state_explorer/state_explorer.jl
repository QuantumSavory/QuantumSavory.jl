using QuantumSavory
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
    "BarrettKokBellPairW" => BarrettKokBellPairW,
    "GenqoUnheraldedSPDCBellPairW" => GenqoUnheraldedSPDCBellPairW,
    "GenqoMultiplexedCascadedBellPairW" => GenqoMultiplexedCascadedBellPairW,
)

const link_dict = Dict(
    "BarrettKokBellPairW" => "BarrettKokBellPair",
    "GenqoUnheraldedSPDCBellPairW" => "Genqo.GenqoUnheraldedSPDCBellPairW",
    "GenqoMultiplexedCascadedBellPairW" => "Genqo.GenqoMultiplexedCascadedBellPairW",
)

landing = Bonito.App(; title="State Explorer") do
    content = md"""
    This app is a tool for exploring the properties of various quantum states as implemented in the [QuantumSavory.StatesZoo](https://qs.quantumsavory.org/dev/API_StatesZoo) package.

    Please select one of the following available states to launch the interactive state explorer app (more available if you run the app locally, see [QuantumSavory.StatesZoo](https://qs.quantumsavory.org/dev/API_StatesZoo):

    - [Barrett-Kok Bell Pair](./vis/BarrettKokBellPairW)
    - [Genqo Unheralded SPDC Bell Pair](./vis/GenqoUnheraldedSPDCBellPairW)
    - [Genqo Multiplexed Cascaded Bell Pair](./vis/GenqoMultiplexedCascadedBellPairW)

    This is simply a web view of the built-in state explorer app, which is implemented in through the [QuantumSavory.StatesZoo.stateexplorer](https://qs.quantumsavory.org/dev/API_StatesZoo/#QuantumSavory.StatesZoo.stateexplorer) function and can be called as:

    ```

    # load interactive plotting package and QuantumSavory modules
    using GLMakie
    using QuantumSavory
    using QuantumSavory.StatesZoo

    stateexplorer(TheStateTypeYouWant) # run the state explorer app locally
    ```

    This is provided as a free visualization and study tool and might be slow to render for particularly complex models. Please run the app locally if you need lower latency and higher performance.

    Some of the implementation details behind the state zoo are discussed in "Full-stack Physics-level model of cascaded entanglement links" in "Advanced Quantum Technologies" the Special Issue on Software for Quantum Networks, as well as in the overview publication on QuantumSavory itself.

    See also the [documentation of QuantumSavory](https://qs.quantumsavory.org/dev/), as well as its [public git repository](https://github.com/QuantumSavory/QuantumSavory.jl).

    The [source code for this app is in the aforementioned git repository](https://github.com/QuantumSavory/QuantumSavory.jl/tree/master/examples/state_explorer).
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
        link = "https://qs.quantumsavory.org/dev/API_StatesZoo/#QuantumSavory.StatesZoo.$(link_dict[statekey])"
        doc = Markdown.Paragraph(Markdown.Link("See the documentation for implemented states.",link))
        content = md"""
        # $(statekey)

        $(fig.scene)

        The Bell pair is shown in the bar plots (both in the Z and in the Bell bases).

        The sliders let you modify various state parameters. For ease of exploration, figures of merit when sweeping one parameter while keeping all others constant are also plotted. The first row corresponds to fidelity (with respect to perfect state) and the second row is the trace of the state (i.e. the probability of successful generation).

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
