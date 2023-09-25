module StatesZoo

using QuantumSymbolics, QuantumOpticsBase
using QuantumSymbolics: withmetadata, @withmetadata, Metadata
import QuantumSymbolics: express_nolookup

export cascaded_source_photonic, cascaded_source_spin, midswap_dual_rail, midswap_single_rail, ZALMpair

abstract type AbstractTwoQubitState <: QuantumSymbolics.AbstractTwoQubitOp end #For representing density matrices
Base.show(io::IO, x::AbstractTwoQubitState) = print(io, "$(symbollabel(x))")

_bspin = SpinBasis(1//2)

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

    
include("cascaded_source/cascaded_source.jl")
include("cascaded_source/ret_cxy.jl")
include("entanglement_swap/entanglement_swap.jl")

end # module