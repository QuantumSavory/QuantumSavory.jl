# implemented in Makie extension

"""An interactive explorer for two-qubit states. It returns a new figure.

Requires a Makie plotting backend to be imported.

```julia
using GLMakie
using QuantumSavory
using QuantumSavory.StatesZoo
stateexplorer(TheStateTypeYouWant) # an interactive Makie figure will be returned
```

See also [`stateexplorer!`](@ref).
"""
function stateexplorer end

"""An interactive explorer for two-qubit states. It modifies the given figure.

Requires a Makie plotting backend to be imported.

See also [`stateexplorer`](@ref).
"""
function stateexplorer! end
