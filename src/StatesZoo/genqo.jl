module Genqo

import Genqo: zalm, spdc
import QuantumSavory.StatesZoo: AbstractTwoQubitState, stateparameters, stateparametersrange, _bspin
import QuantumSymbolics: Metadata # TODO fix the @withmetadata macro to not require this import
import QuantumSymbolics: @withmetadata, symbollabel, QuantumOpticsRepr, express_nolookup, ⊗
import QuantumOpticsBase
using DocStringExtensions

"""
$TYPEDEF

Fields:

$FIELDS

Heralded multiplexed cascaded source (a.k.a. single mode model for zero added loss multiplexed (ZALM) source).

The state is not normalized and its trace corresponds to the probability of successful heralding.

Based on the cascaded source from [prajit2022heralded](@cite) and [kevin2023zero](@cite).

Functions are included for both the photon-photon state as well as the spin-spin state following loading using Duan-Kimble style quantum memories

Implemented as a wrapper around the `Genqo.jl` package.
"""
@withmetadata struct GenqoMultiplexedCascadedBellPairW <: AbstractTwoQubitState
    """Loss (transmissivity) in the Bell state measurement at the source (modes 3, 4, 5, 6), ∈[0,1]"""
    ηᵇ
    """Loss (transmissivity) in all of the detectors, ∈[0,1]"""
    ηᵈ
    """Outcoupling transmissivity for the bell-state modes (1,2,7,8), ∈[0,1]"""
    ηᵗ
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the 2-photon cutoff of the Fock space used in derivation)"""
    N
    """Excess noise (photons per qubit slot) in photon detectors, ≥0, usually ≪1"""
    Pᵈ
end

stateparameters(::Type{GenqoMultiplexedCascadedBellPairW}) = (:ηᵇ, :ηᵈ, :ηᵗ, :N, :Pᵈ)
stateparametersrange(::Type{GenqoMultiplexedCascadedBellPairW}) = (
    ηᵇ =(;min=0,max=1,good=1),
    ηᵈ =(;min=0,max=1,good=1),
    ηᵗ =(;min=0,max=1,good=1),
    N  =(;min=0,max=10,good=0.1),
    Pᵈ =(;min=0,max=0.1,good=1e-8)
)

function _express_spin_spin_matrix(x::GenqoMultiplexedCascadedBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    # `Pᵈ` remains part of the wrapper API for compatibility, but Genqo.jl's
    # spin-density-matrix backend does not currently take dark counts.
    (;ηᵇ, ηᵈ, ηᵗ, N) = x
    return zalm.spin_density_matrix(N, ηᵗ, ηᵈ, ηᵇ, [1,0,1,1,0,0,1,0])
end

symbollabel(x::GenqoMultiplexedCascadedBellPairW) = "ρᶻᵃˡᵐ"

function express_nolookup(x::GenqoMultiplexedCascadedBellPairW, ::QuantumOpticsRepr)
    mat = _express_spin_spin_matrix(x)
    return QuantumOpticsBase.SparseOperator(_bspin⊗_bspin, mat)
end

"""
$TYPEDEF

Fields:

$FIELDS

Unheralded source of polarization Bell pairs, as described by [kwiat1995new](@cite).

Functions are included for both the photon-photon state as well as the spin-spin state following loading using Duan-Kimble style quantum memories

Implemented as a wrapper around the `Genqo.jl` package.
"""
@withmetadata struct GenqoUnheraldedSPDCBellPairW <: AbstractTwoQubitState
    """Loss (transmissivity) in all of the detectors, ∈[0,1]"""
    ηᵈ
    """Outcoupling transmissivity for the bell-state modes (1,2,3,4), ∈[0,1]"""
    ηᵗ
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the 2-photon cutoff of the Fock space used in derivation)"""
    N
    """Excess noise (photons per qubit slot) in photon detectors, ≥0, usually ≪1"""
    Pᵈ
end

stateparameters(::Type{GenqoUnheraldedSPDCBellPairW}) = (:ηᵈ, :ηᵗ, :N, :Pᵈ)
stateparametersrange(::Type{GenqoUnheraldedSPDCBellPairW}) = (
    ηᵈ =(;min=0,max=1,good=1),
    ηᵗ =(;min=0,max=1,good=1),
    N   =(;min=0,max=10,good=0.1),
    Pᵈ  =(;min=0,max=0.1,good=10^(-6))
)

function _express_spin_spin_matrix(x::GenqoUnheraldedSPDCBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    # `Pᵈ` remains part of the wrapper API for compatibility, but Genqo.jl's
    # spin-density-matrix backend does not currently take dark counts.
    (;ηᵈ, ηᵗ, N) = x
    return spdc.spin_density_matrix(N, ηᵗ, ηᵈ, [0,1,0,1])
end

symbollabel(x::GenqoUnheraldedSPDCBellPairW) = "ρˢᵖᵈᶜ"

function express_nolookup(x::GenqoUnheraldedSPDCBellPairW, ::QuantumOpticsRepr)
    mat = _express_spin_spin_matrix(x)
    return QuantumOpticsBase.SparseOperator(_bspin⊗_bspin, mat)
end

end
