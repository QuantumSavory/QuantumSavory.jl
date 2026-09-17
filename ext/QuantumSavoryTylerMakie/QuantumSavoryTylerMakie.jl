module QuantumSavoryTylerMakie

using QuantumSavory
using Makie
using Tyler
using Tyler.MapTiles
using Tyler.TileProviders
import QuantumSavory: generate_map

"""
    generate_map([subfig]; extent=nothing, provider=TileProviders.OpenStreetMap())

Generate a map and return its figure region, axis, and `Tyler.Map`. The returned axis can be used
as an input for `registernetplot_axis`. Pass a `TileProviders.Provider` to select a custom tile
service.
""" # subfig::Union{GridPosition, GridSubposition} but maybe other as well, so leave it unspecified
function generate_map(subfig; extent=nothing, provider=TileProviders.OpenStreetMap())
    if isnothing(extent)
        extent = Rect2f(-125, 24, 58, 25) # US Map
    end
    map = Tyler.Map(extent; provider, figure=subfig, crs=Tyler.wgs84)
    wait(map)
    return subfig, map.axis, map
end

function generate_map(; extent=nothing, provider=TileProviders.OpenStreetMap())
    fig = Makie.Figure()
    generate_map(fig; extent, provider)
end

end
