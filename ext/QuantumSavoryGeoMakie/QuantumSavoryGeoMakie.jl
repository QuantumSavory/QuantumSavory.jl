module QuantumSavoryGeoMakie

import Makie, GeoMakie
using GeoMakie: GeoAxis, image!, poly!, naturalearth

"""Generates a default map with country and state boundaries and returns a GeoAxis. The returned GeoAxis can be used as an input for registernetplot_axis."""
function generate_map(subfig::Makie.GridPosition)
    ax = GeoAxis(subfig; limits=((-180, 180), (-90, 90)), dest="+proj=longlat +datum=WGS84")
    countries = naturalearth("admin_0_countries", 110)
    states = naturalearth("admin_1_states_provinces_lakes", 110)
    image!(ax, -180..180, -90..90, GeoMakie.earth() |> rotr90; interpolate=false, inspectable=false)
    poly!(ax, GeoMakie.land(); color=:lightyellow, strokecolor=:black, strokewidth=1, inspectable=false)
    poly!(ax, GeoMakie.to_multipoly.(countries.geometry), color=:transparent, strokecolor=:black, strokewidth=1, inspectable=false)
    poly!(ax, GeoMakie.to_multipoly.(states.geometry); color=:transparent, strokecolor=:grey, strokewidth=0.7, inspectable=false)
    return ax
end

function generate_map()
    fig = Makie.Figure()
    generate_map(fig)
end

end