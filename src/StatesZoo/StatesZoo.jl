module StatesZoo

using DocStringExtensions
using QuantumSymbolics, QuantumOpticsBase
using QuantumSymbolics: @withmetadata, Metadata
import QuantumSymbolics: express_nolookup, symbollabel

import LinearAlgebra
import LinearAlgebra: tr

export BarrettKokBellPair, BarrettKokBellPairW,
    stateexplorer, stateexplorer!, stateparameters, stateparametersrange


# TODO this abstract type should specify isexpr()==false
abstract type AbstractTwoQubitState <: QuantumSymbolics.AbstractTwoQubitOp end #For representing density matrices
Base.show(io::IO, x::AbstractTwoQubitState) = print(io, "$(symbollabel(x))")
symbollabel(x::AbstractTwoQubitState) = "ρᵖᵃⁱʳ"

_bspin = SpinBasis(1//2)

"""Return the "interesting" parameters that a state from the StatesZoo has. A constructor that uses only these parameters needs to exist.

Used by `stateexplorer` to generate the most valuable plots of figures of merit."""
function stateparameters end
"""Return the valid ranges and the "good" value for all parameters listed in `stateparameters`."""
function stateparametersrange end
stateparameters(::Any) = ()
stateparametersrange(::Any) = ()

include("barrett_kok.jl")

include("genqo.jl")

include("state_explorer.jl")

end # module
