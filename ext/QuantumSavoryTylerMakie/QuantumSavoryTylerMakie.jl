module QuantumSavoryTylerMakie

using QuantumSavory
using Makie
using Tyler
using Tyler.MapTiles
using Tyler.TileProviders
import QuantumSavory: generate_map

"""
Generates a default map and returns an axis. The returned axis can be used as an input for `registernetplot_axis`.
""" # subfig::Union{GridPosition, GridSubposition} but maybe other as well, so leave it unspecified
function generate_map(subfig; extent=nothing)
    if isnothing(extent)
        extent = Rect2f(-125, 24, 58, 25) # US Map
    end
    provider = TileProviders.CartoDB(:Positron)
    map = Tyler.Map(extent; provider, figure=subfig, crs=Tyler.wgs84)
    wait(map; timeout=100)
    return subfig, map.axis, map
end

function generate_map(;extent=nothing)
    fig = Makie.Figure()
    generate_map(fig; extent)
end

end
