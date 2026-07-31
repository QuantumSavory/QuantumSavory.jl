module StatesZoo

using DocStringExtensions
using QuantumSymbolics, QuantumOpticsBase
using QuantumSymbolics: @withmetadata, Metadata
import QuantumSymbolics: express_nolookup, symbollabel

import LinearAlgebra
import LinearAlgebra: tr

export BarrettKokBellPair, BarrettKokBellPairW,
    DepolarizedBellPair,
    StateNormalizationStyle, NormalizedState, WeightedState,
    StateParameterSchema, StateFamilySchema,
    state_family_schema, state_family_schemas, state_normalization_style,
    state_weight, normalized_state_and_weight,
    stateexplorer, stateexplorer!, stateparameters, stateparametersrange


# TODO this abstract type should specify isexpr()==false
abstract type AbstractTwoQubitState <: QuantumSymbolics.AbstractTwoQubitOp end #For representing density matrices
Base.show(io::IO, x::AbstractTwoQubitState) = print(io, "$(symbollabel(x))")
symbollabel(x::AbstractTwoQubitState) = "ρᵖᵃⁱʳ"

_bspin = SpinBasis(1//2)

include("barrett_kok.jl")

include("depolarized.jl")

include("genqo.jl")

include("metadata.jl")

include("state_explorer.jl")

end # module
