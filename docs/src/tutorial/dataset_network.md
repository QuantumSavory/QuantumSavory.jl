# [Build a Network from a Dataset](@id dataset-network)

This tutorial loads a published network topology, converts its link distances
to propagation delays, and schedules node and link protocols.

## Load the topology

```@example dataset_network
using CairoMakie
using CommunicationNetworkDatasets
using QuantumSavory
using QuantumSavory.ProtocolZoo: EntanglerProt, EntanglementTracker
using Tyler

CairoMakie.activate!(; visible=false) # hide

topology = load_network("topology_bench", "arpanet")
delays = dist_to_delay(topology.distances);
```

The dataset reports distances in metres. [`dist_to_delay`](@ref) uses a default
propagation speed of ``2.0 \times 10^8`` metres per second and returns a new
edge-keyed dictionary.

## Build and schedule the network

```@example dataset_network
node_protocols = (EntanglementTracker => (;),)
link_protocols = (EntanglerProt => (;),)

(; sim, network) = network_builder(
    topology.graph,
    delays,
    (2,);
    node_protocols,
    link_protocols,
);
```

The empty named tuples select the protocol defaults. [`network_builder`](@ref)
creates a two-slot register at every vertex. It applies `EntanglementTracker`
to every node and `EntanglerProt` to every undirected edge. It also uses each
edge delay for both directions of the classical and quantum channels.

The protocols are scheduled, but the builder does not advance `sim`.

## Plot the register locations

The node table gives longitude and latitude in the same vertex order as the
graph. Pass those coordinates to the register plot on a Tyler map.

```@example dataset_network
coordinates = Point2f.(
    topology.nodes.longitude_deg,
    topology.nodes.latitude_deg,
)

tile_url = "https://tiles.quantumsavory.org/styles/ci/{z}/{x}/{y}.png" # hide
ci_key = get(ENV, "TILE_CI_KEY", "") # hide
isempty(ci_key) || occursin(r"\A[0-9a-f]{64}\z", ci_key) || # hide
    error("TILE_CI_KEY must contain 64 lowercase hexadecimal characters") # hide
tile_url *= isempty(ci_key) ? "" : "?ci_key=$(ci_key)" # hide
provider = Tyler.TileProviders.Provider( # hide
    tile_url; # hide
    max_zoom=13, # hide
    attribution="Protomaps © OpenStreetMap contributors; hosted by QuantumSavory", # hide
) # hide
if false # hide
fig, axis, map = generate_map()
end # hide
fig, axis, map = generate_map(; provider) # hide
registernetplot_axis(axis, network; registercoords=coordinates);
wait(map) # hide
close(map) # hide
fig
```

The simulation is still at time zero, so the figure contains only the empty
register glyphs. It does not draw physical graph edges or generated
quantum-state links.

!!! note "Dataset attribution"
    This tutorial uses the ARPANET topology from Virgillito et al.,
    *Topology Bench: Systematic Graph Based Benchmarking for Optical Networks*,
    [Zenodo record 13921775 (2024)](https://zenodo.org/records/13921775), under
    the [Creative Commons Attribution 4.0 International
    license](https://creativecommons.org/licenses/by/4.0/). Attribute the
    Topology Bench authors and the per-topology sources named by that
    collection. CommunicationNetworkDatasets.jl publishes a modified form with
    normalized schemas and identifiers, distances converted from kilometres to
    metres, and documented self-loops and duplicate undirected edges removed.
    Basemap tiles: Protomaps © OpenStreetMap contributors; hosted by
    QuantumSavory.

Call `run(sim, stop_time)` separately when you are ready to run the protocols.
Use more register slots if protocols on several incident links must retain
entanglement at the same time.
