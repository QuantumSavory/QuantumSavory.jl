"""
    registernetplot(regnet::RegisterNet; kwargs...)

Draw the given register network in a new figure window.

Requires a Makie backend be already imported (e.g. `using CairoMakie` or `using GLMakie`).

The plot shows:
- Register nodes as gray rounded rectangles, sized to fit all slots
- Register slots as small gray rectangles arranged vertically
- State subsystems (quantum states stored in register slots) as black diamonds
- Entanglement links as gray lines connecting subsystems belonging to the same composite state
- Observable expectation values as colored dots with a spectral colormap
- Lock indicators (🔒) on locked slots
- Tag markers as colored shapes next to tagged slots (#66)
- Message-buffer dot indicators (blue circles) showing pending message count (#96)
- Quantum channel in-flight state markers (orange pentagons) along edges (#97)

Hover over any element to see detailed tooltips:
- **Register slots**: Shows register index, slot index, tags, lock status,
  state info (Bloch vector components for qubits, density matrix diagonal for
  larger states), and message buffer contents (#96)
- **State diamonds**: Shows which composite state the subsystem belongs to,
  entangled partner slots, Bloch/density-matrix info (#98), and tags
- **Tag markers**: Shows the full tag representation (#66)
- **Message-buffer dots**: Shows all pending classical messages (#96)
- **Quantum channel markers**: Shows in-flight state info with queue depth (#97)
- **Observable dots**: Shows the observable operator and its expectation value

## Keyword arguments

- `registercoords::Vector{<:Point2}`: Manual positions for each register node.
  Auto-generated via `NetworkLayout.spring` if not provided.
- `observables::Vector{Tuple{Any,Tuple{Vararg{Tuple{Int,Int}}}}}`:
  Observable operators to evaluate and display. Each element is
  `(operator, ((reg,slot), ...))` or with an optional third element for custom links.
- `scale::Float64=1.0`: Global scaling factor for all visual elements.
- `slotcolor`: Color for slot markers. Can be a single color, a vector of colors
  (one per slot), or a vector of vectors (one per register).
- `colormap=:Spectral`: Colormap for observable values.
- `colorrange=(-1.0, 1.0)`: Range for observable color mapping.
- `register_color=:gray90`: Fill color for register rectangles.
- `slotmarker=:rect`: Marker shape for register slots.
- `slotsize=0.8`: Size of slot markers.
- `state_marker=:diamond`: Marker shape for stored states.
- `state_markercolor=:black`: Color for state markers.
- `state_linecolor=:gray90`: Color for entanglement links.

### Tag marker options (#66)
- `tag_markers_enabled=true`: Show colored tag markers on tagged slots.
- `tag_markersize=0.2`: Size of tag marker shapes.
- `tag_label_enabled=false`: Show short text labels next to tag markers.

### Message-buffer options (#96)
- `mb_markers_enabled=true`: Show message-buffer indicator dots.
- `mb_markersize=0.12`: Size of indicator dots.

### Quantum channel options (#97)
- `qch_markers_enabled=true`: Show in-flight quantum state markers.
- `qch_markersize=0.15`: Size of in-flight state markers.

See also: [`registernetplot!`](@ref), [`registernetplot_axis`](@ref), [`resourceplot_axis`](@ref)
"""
function registernetplot end

"""
    registernetplot!(ax::Makie.AbstractAxis, regnet::RegisterNet; kwargs...)

Draw the given register network onto an existing Makie axis.
All keyword arguments are the same as [`registernetplot`](@ref).

See also: [`registernetplot`](@ref), [`registernetplot_axis`](@ref)
"""
function registernetplot! end

"""
    registernetplot_axis([subfig,] regnet::RegisterNet; kwargs...)

Draw the given register network on a given Makie axis or subfigure, modifying
the axis with numerous visualization enhancements:

- Hides axis decorations and spines unless `hidedecorations=false`
- Disables rectangle zoom interaction
- Registers an info CLI interaction handler (click on elements for terminal output)
- Attaches a `DataInspector` for hover tooltips
- Translates the plot in front of background map layers
- Sets `DataAspect()` for the axis

Returns `(subfigure, axis, plot, observable)` where `observable` can be notified
to update the plot when the network changes.

See [`registernetplot`](@ref) for keyword arguments.

## Extended help

```julia
using QuantumSavory, CairoMakie

net = RegisterNet([Register(2), Register(3)])
_, ax, p, obs = registernetplot_axis(net)

# Update the plot after modifying the network:
initialize!(net[1,1], X1)
notify(obs)
```

See also: [`generate_map`](@ref), [`resourceplot_axis`](@ref)
"""
function registernetplot_axis end

"""
    resourceplot_axis(subfig, network, edgeresources, vertexresources; registercoords=nothing, title="")

Draw the various resources and locks stored in the given meta-graph on a
given Makie axis.

Resources can be booleans, ConcurrentSim.Resource locks, or any type for which
[`showonplot`](@ref) is defined.

Returns `(subfig, axis, plot, observable)` where `observable` can be notified
to update the plot when resources change.

## Example

```julia
network[v, :resource] = Resource(sim, 1)
request(network[v, :resource])
resourceplot_axis(fig[1,1], network, [:bool], [:resource])
```
"""
function resourceplot_axis end

"""
    showonplot(x) -> Bool

Return whether the resource `x` should be shown on a plot.
Defaults: `ConcurrentSim.Resource` → `islocked(r)`, `Bool` → identity.
"""
function showonplot end

"""
    showmetadata(fig, ax, plot, reg_index, slot_index)

Programmatically trigger the metadata tooltip for a given register slot,
simulating a mouse hover at the appropriate position.
"""
function showmetadata end

"""
    generate_map([subfig]; extent=nothing)

Generates a default map with country and state boundaries and returns a
`GeoAxis`. The returned axis can be used as an input for `registernetplot_axis`.

The `Tyler` package must be installed and imported.

Returns `(subfig, axis, map)` where `axis` can be passed to
`registernetplot_axis` as the first argument.

## Example

```julia
using Tyler, CairoMakie
fig, map_axis, map = generate_map()
coords = [Point2f(-71, 42), Point2f(-111, 34)]
_, _, plt, netobs = registernetplot_axis(map_axis, network, registercoords=coords)
```
"""
function generate_map end
