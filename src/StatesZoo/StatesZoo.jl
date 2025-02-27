module StatesZoo

using DocStringExtensions
using QuantumSymbolics, QuantumOpticsBase
using QuantumSymbolics: @withmetadata, Metadata
import QuantumSymbolics: express_nolookup

import LinearAlgebra
import LinearAlgebra: tr

export SingleRailMidSwapBellW, SingleRailMidSwapBell,
    DualRailMidSwapBellW, DualRailMidSwapBell,
    ZALMSpinPairW, ZALMSpinPair,
    BarrettKokBellPair, BarrettKokBellPairW,
    stateexplorer, stateexplorer!, stateparameters, stateparametersrange

# TODO this abstract type should specify isexpr()==false
abstract type AbstractTwoQubitState <: QuantumSymbolics.AbstractTwoQubitOp end #For representing density matrices
Base.show(io::IO, x::AbstractTwoQubitState) = print(io, "$(symbollabel(x))")

_bspin = SpinBasis(1//2)

"""Return the "interesting" parameters that a state from the StatesZoo has. A constructor that uses only these parameters needs to exist.

Used by `stateexplorer` to generate the most valuable plots of figures of merit."""
function stateparameters end
"""Return the valid ranges and the "good" value for all parameters listed in `stateparameters`."""
function stateparametersrange end
stateparameters(::Any) = ()
stateparametersrange(::Any) = ()

const cascaded_source_basis = [0 0 0 0;
                               0 0 0 1;
                               0 0 0 2;
                               0 0 1 0;
                               0 0 1 1;
                               0 0 2 0;
                               0 1 0 0;
                               0 1 0 1;
                               0 1 0 2;
                               0 1 1 0;
                               0 1 1 1;
                               0 1 2 0;
                               0 2 0 0;
                               0 2 0 1;
                               0 2 0 2;
                               0 2 1 0;
                               0 2 1 1;
                               0 2 2 0;
                               1 0 0 0;
                               1 0 0 1;
                               1 0 0 2;
                               1 0 1 0;
                               1 0 1 1;
                               1 0 2 0;
                               1 1 0 0;
                               1 1 0 1;
                               1 1 0 2;
                               1 1 1 0;
                               1 1 1 1;
                               1 1 2 0;
                               2 0 0 0;
                               2 0 0 1;
                               2 0 0 2;
                               2 0 1 0;
                               2 0 1 1;
                               2 0 2 0]


include("zalm_pair/zalm_pair.jl")
include("zalm_pair/ret_cxy.jl")
include("single_dual_rail_midswap/single_dual_rail_midswap.jl")

include("barrett_kok.jl")

include("state_explorer.jl")

end # module
