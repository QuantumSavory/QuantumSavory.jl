module QuantumSavoryGeoMakie

using QuantumSavory
using GeoMakie 
import GeoMakie: GeoAxis, image!, poly!, naturalearth, Makie
import QuantumSavory: generate_map

"""
Generates a default map with country and state boundaries and returns a GeoAxis. The returned GeoAxis can be used as an input for `registernetplot_axis`.

For borders, the optional `scale` parameter can be set to 10, 50, or 110, corresponding to Natural Earth resolutions of 1:10m, 1:50m, and 1:110m.
"""
function generate_map(subfig::Makie.GridPosition, scale::Int=110)
    if scale ∉ (10, 50, 110)
        error("Invalid scale value: scale must be 10, 50, or 110.")
    end
    
    ax = GeoAxis(subfig; limits=((-180, 180), (-90, 90)), dest="+proj=longlat +datum=WGS84")
    countries = naturalearth("admin_0_countries", scale)
    states = naturalearth("admin_1_states_provinces_lakes", scale)
    image!(ax, (-180, 180), (-90, 90), GeoMakie.earth() |> rotr90; interpolate=false, inspectable=false)
    poly!(ax, GeoMakie.land(); color=:lightyellow, strokecolor=:transparent, inspectable=false)
    poly!(ax, GeoMakie.to_multipoly.(countries.geometry), color=:transparent, strokecolor=(:black, 0.5), strokewidth=0.7, inspectable=false)
    poly!(ax, GeoMakie.to_multipoly.(states.geometry); color=:transparent, strokecolor=(:grey, 0.5), strokewidth=0.5, inspectable=false)
    
    #ax.scene.paddings[] = 0 
    #Makie.hidemargins!(ax)
    tightlimits!(ax)  
    
    return ax
end

function generate_map()
    fig = Makie.Figure()
    generate_map(fig[1, 1])
end

end
