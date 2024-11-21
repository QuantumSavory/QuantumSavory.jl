"""Draw the given register network.

Requires a Makie backend be already imported."""
function registernetplot(args...; kwargs...)
    ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    if isnothing(ext)
        throw("`registernetplot` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
    end
    return ext.registernetplot(args...; kwargs...)
end

"""Draw the given register network on a given Makie axis.

Requires a Makie backend be already imported."""
function registernetplot!(args...; kwargs...)
    ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    if isnothing(ext)
        throw("`registernetplot!` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
    end
    return ext.registernetplot!(args...; kwargs...)
end

"""Draw the given register network on a given Makie axis or subfigure and modify the axis with numerous visualization enhancements.

Requires a Makie backend be already imported."""
function registernetplot_axis(args...; kwargs...)
    ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    if isnothing(ext)
        throw("`registernetplot_axis` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
    end
    return ext.registernetplot_axis(args...; kwargs...)
end

"""Draw the various resources and locks stored in the given meta-graph on a given Makie axis.

Requires a Makie backend be already imported."""
function resourceplot_axis(args...; kwargs...)
    ext = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
    if isnothing(ext)
        throw("`resourceplot_axis` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
    end
    return ext.resourceplot_axis(args...; kwargs...)
end

"""Show the metadata tooltip for a given register slot.

Requires a Makie backend be already imported."""
function showmetadata end

function showonplot end

"""Generates a default map with country and state boundaries and returns a GeoAxis. The returned GeoAxis can be used as an input for registernetplot_axis.

The `GeoMakie` package must be installed and imported."""
function generate_map(args...; kwargs...)
    ext = Base.get_extension(QuantumSavory, :QuantumSavoryGeoMakie)
    if isnothing(ext)
        throw("`generate_map` requires the package `GeoMakie`; please make sure `GeoMakie` is installed and imported first.")
    end
    return ext.generate_map(args...; kwargs...)
end