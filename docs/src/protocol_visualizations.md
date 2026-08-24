# [Protocol Visualizations](@id protocol-visualizations)

Protocols can provide rich `text/html` and `image/png` displays for notebooks,
integrated development environments, and other rich display frontends. This
page shows both renderings for every protocol that implements them.

```@setup protocol_visualizations
using CairoMakie
using ConcurrentSim
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ResumableFunctions

CairoMakie.activate!()

function protocolvis_html(protocol)
    return Base.HTML(sprint(show, MIME"text/html"(), protocol))
end

struct ProtocolVisualizationPNG
    protocol
end

Base.show(io::IO, mime::MIME"image/png", image::ProtocolVisualizationPNG) =
    show(io, mime, image.protocol)

basic_net = RegisterNet(
    [Register(5), Register(5)];
    classical_delay=1e-9,
    names=["Alice", "Bob"],
)
entangler = EntanglerProt(basic_net, 1, 2; success_prob=0.25)
consumer = EntanglementConsumer(basic_net, 1, 2; period=0.1)
@process EntanglerProt(basic_net, 1, 2; rounds=5, success_prob=1.0)()
@process consumer()
run(get_time_tracker(basic_net), 1.0)

qtcp_net = RegisterNet(
    path_graph(5),
    [Register(12) for _ in 1:5];
    classical_delay=1e-6,
    names=["Amherst", "Boston", "Cambridge", "Dover", "Essex"],
)
qtcp_sim = get_time_tracker(qtcp_net)
end_controllers = Dict(
    node => EndNodeController(qtcp_net, node) for node in (1, 2, 4, 5)
)
network_controllers = [
    NetworkNodeController(qtcp_net, node) for node in vertices(qtcp_net)
]
link_controllers = [
    LinkController(qtcp_net, edge.src, edge.dst) for edge in edges(qtcp_net)
]
for controller in values(end_controllers)
    @process controller()
end
for controller in network_controllers
    @process controller()
end
for controller in link_controllers
    @process controller()
end
put!(qtcp_net[1], Flow(src=1, dst=5, npairs=2, uuid=301))
put!(qtcp_net[4], Flow(src=4, dst=2, npairs=2, uuid=302))
run(qtcp_sim, 12.0)

link_controller = link_controllers[2]
external_link_controller = LinkController(
    qtcp_net,
    2,
    3;
    tag=EntanglementCounterpart,
    filo=false,
)
network_controller = network_controllers[3]
end_controller = end_controllers[2]
```

## [`EntanglerProt`](@ref)

### `text/html`

```@example protocol_visualizations
protocolvis_html(entangler) # hide
```

### `image/png`

```@example protocol_visualizations
ProtocolVisualizationPNG(entangler) # hide
```

## [`EntanglementConsumer`](@ref)

### `text/html`

```@example protocol_visualizations
protocolvis_html(consumer) # hide
```

### `image/png`

```@example protocol_visualizations
ProtocolVisualizationPNG(consumer) # hide
```

## [`LinkController`](@ref)

The integrated mode shows its one-shot entangler. The external mode shows the
configured inventory tag and selection order.

### Integrated `text/html`

```@example protocol_visualizations
protocolvis_html(link_controller) # hide
```

### Integrated `image/png`

```@example protocol_visualizations
ProtocolVisualizationPNG(link_controller) # hide
```

### External-Inventory `text/html`

```@example protocol_visualizations
protocolvis_html(external_link_controller) # hide
```

### External-Inventory `image/png`

```@example protocol_visualizations
ProtocolVisualizationPNG(external_link_controller) # hide
```

## [`NetworkNodeController`](@ref)

### `text/html`

```@example protocol_visualizations
protocolvis_html(network_controller) # hide
```

### `image/png`

```@example protocol_visualizations
ProtocolVisualizationPNG(network_controller) # hide
```

## [`EndNodeController`](@ref)

### `text/html`

```@example protocol_visualizations
protocolvis_html(end_controller) # hide
```

### `image/png`

```@example protocol_visualizations
ProtocolVisualizationPNG(end_controller) # hide
```
