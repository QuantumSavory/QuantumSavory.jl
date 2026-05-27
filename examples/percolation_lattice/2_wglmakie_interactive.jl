using WGLMakie
WGLMakie.activate!()
import Bonito
using Markdown

include("interactive_dashboard.jl")

const custom_css = Bonito.DOM.style("ul {list-style: circle !important;}")

landing = Bonito.App() do
    fig = build_dashboard()
    content = md"""
    $(fig.scene)

    # Heralded entanglement percolation on a repeater lattice

    Each edge represents one nearest-neighbor elementary Bell-pair generation
    attempt. Green edges succeeded in the current heralding round. If Alice and
    Bob are connected, the selected shortest swapping path is highlighted in red.

    The plots on the right summarize repeated seeded trials for the current
    parameters, showing how the lattice crosses from mostly disconnected to
    mostly connected as the elementary link success probability increases.
    """
    return Bonito.DOM.div(Bonito.MarkdownCSS, Bonito.Styling, custom_css, content)
end

isdefined(Main, :server) && close(server)
port = parse(Int, get(ENV, "QS_PERCOLATION_PORT", "8894"))
interface = get(ENV, "QS_PERCOLATION_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_PERCOLATION_PROXY", "")
server = Bonito.Server(interface, port; proxy_url)
Bonito.HTTPServer.start(server)
Bonito.route!(server, "/" => landing)

@info "app server is running on http://$(interface):$(port) | proxy_url=`$(proxy_url)`"

if abspath(PROGRAM_FILE) == @__FILE__
    wait(server)
end
