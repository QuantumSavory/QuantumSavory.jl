module QuantumSavoryTylerMakie

using QuantumSavory
using Makie
using Tyler
using Tyler.MapTiles
import QuantumSavory: generate_map

"""
Generates a default map and returns an axis. The returned axis can be used as an input for `registernetplot_axis`.
"""
function generate_map(subfig::Makie.GridPosition; extent=nothing)
    if isnothing(extent)
        extent = Rect2f(-125, 24, 58, 25) # US Map
    end
    map = Tyler.Map(extent; figure=subfig, crs=Tyler.wgs84)
    return map.axis
end

function generate_map(;extent=nothing)
    fig = Makie.Figure()
    generate_map(fig[1, 1]; extent)
end

end
