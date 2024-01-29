"""Draw the given register network.

Requires a Makie backend be already imported."""
function registernetplot end

"""Draw the given register network on a given Makie axis.

Requires a Makie backend be already imported."""
function registernetplot! end

"""Draw the given register network on a given Makie subfigure and modify the axis with numerous visualization enhancements.

Requires a Makie backend be already imported."""
function registernetplot_axis end

"""Draw the various resources and locks stored in the given meta-graph on a given Makie axis.

Requires a Makie backend be already imported."""
function resourceplot_axis end

function showonplot end
