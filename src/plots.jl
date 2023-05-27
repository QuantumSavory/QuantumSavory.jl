export registernetplot, registernetplot_axis, resourceplot_axis

"""Draw the given registers on a given Makie axis.

Requires a Makie backend be already imported."""
function registernetplot end

"""Draw the given registers on a given Makie axis.

Requires a Makie backend be already imported."""
function registernetplot_axis end

"""Draw the various resources and locks stored in the given meta-graph on a given Makie axis.

Requires a Makie backend be already imported."""
function resourceplot_axis end

function showonplot end
