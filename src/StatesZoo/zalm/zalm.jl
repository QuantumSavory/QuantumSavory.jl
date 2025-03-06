module SPDC_HMCS_compilation_module
    using Symbolics: build_function, @variables
    using LinearAlgebra: tr
    @variables eA, eB, eC1, eC2, Ns, Pd, vis
    include("dens_mat_SPDC.jl")
    _dens_mat_SPDC_notnorm_expr = _dens_mat_SPDC(eA, eB, Ns)
    _dens_mat_SPDC_tr_expr = tr(_dens_mat_SPDC_notnorm_expr)
    const _dens_mat_SPDC_notnorm! = build_function(_dens_mat_SPDC_notnorm_expr, eA, eB, Ns; expression=Val(false))[2]
    const _dens_mat_SPDC_tr = build_function(_dens_mat_SPDC_tr_expr, eA, eB, Ns; expression=Val(false))[1] #TODO run simplify
    include("dens_mat_HMCS.jl")
    _dens_mat_HMCS_notnorm_expr = _dens_mat_HMCS(eA, eB, eC1, eC2, Ns, Pd, vis)
    _dens_mat_HMCS_tr_expr = tr(_dens_mat_HMCS_notnorm_expr)
    const _dens_mat_HMCS_notnorm! = build_function(_dens_mat_HMCS_expr, eA, eB, eC1, eC2, Ns, Pd, vis; expression=Val(false))[2]
end

const _dens_mat_SPDC! = SPDC_HMCS_compilation_module._dens_mat_SPDC!
const _dens_mat_HMCS! = SPDC_HMCS_compilation_module._dens_mat_HMCS!

"""SPDC based Polarization Entanglement generation source -- three-level Fock space cutoff"""
function _dens_mat_SPDC(eA, eB, Ns) # TODO use a sparse matrix
    ρ = zeros(ComplexF64, (81, 81))
    _dens_mat_SPDC!(ρ, eA, eB, Ns)
    return ρ
end

"""heralded multiplexed cascaded source (a.k.a. single mode model for zero added loss multiplexed/ZALM source) -- three-level Fock space cutoff"""
function _dens_mat_HMCS(eA, eB, eC1, eC2, Ns, Pd, vis) # TODO use a sparse matrix
    ρ = zeros(ComplexF64, (81, 81))
    _dens_mat_SPDC!(ρ, eA, eB, eC1, eC2, Ns, Pd, vis)
    return ρ
end

"""
$TYPEDEF

Fields:

$FIELDS

SPDC based Polarization Entanglement generation source.
The two modes each live in Fock spaces of n≤2 photons (the model does not track higher excitations).
The state is not normalized and its trace corresponds to the probability of successful heralding.
"""
@withmetadata struct PolarizationSPDCBellPhotonsW # TODO <: AbstractTwoQubitState
    """Outcoupling transmissivity on Alice’s side (or signal), ∈[0,1]"""
    ηᴬ
    """Outcoupling transmissivity on Bob’s side (or idler), ∈[0,1]"""
    ηᴮ
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the n=2 cutoff of the Fock space used in derivation)"""
    N
end
"""The normalized version of [`PolarizationSPDCBellPhotonsW`](@ref)."""
@withmetadata struct PolarizationSPDCBellPhotons # TODO <: AbstractTwoQubitState
    spdc::PolarizationSPDCBellPhotonsW
end

"""
$TYPEDEF

Fields:

$FIELDS

Heralded multiplexed cascaded source (a.k.a. single mode model for zero added loss multiplexed/ZALM source).
The two modes each live in Fock spaces of n≤2 photons (the model does not track higher excitations).
The state is not normalized and its trace corresponds to the probability of successful heralding.
"""
@withmetadata struct MultiplexedCascadedBellPhotonsW # TODO <: AbstractTwoQubitState
    """Outcoupling transmissivity on Alice’s side (or signal), ∈[0,1]"""
    ηᴬ
    """Outcoupling transmissivity on Bob’s side (or idler), ∈[0,1]"""
    ηᴮ
    """Coupling from SPDC source 1 to linear optical BSM (implicitly must account for detection efficiency)"""
    ηᶜ¹
    """Coupling from SPDC source 2 to linear optical BSM (implicitly must account for detection efficiency)"""
    ηᶜ²
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the n=2 cutoff of the Fock space used in derivation)"""
    N
    """Total excess noise (photons per qubit slot) in photon detectors, ≥0, usually ≪1 """
    Pᵈ
    """Swap visibility product, ∈[0,1]"""
    vis
end
"""The normalized version of [`MultiplexedCascadedBellPhotonsW`](@ref)."""
@withmetadata struct MultiplexedCascadedBellPhotons # TODO <: AbstractTwoQubitState
    hmcs::MultiplexedCascadedBellPhotonsW
end

stateparameters(::Type{PolarizationSPDCBellPhotonsW}) = (:ηᴬ, :ηᴮ, :N)
stateparameters(::Type{MultiplexedCascadedBellPhotonsW}) = (:ηᴬ, :ηᴮ, :ηᶜ¹, :ηᶜ², :N, :Pᵈ, :vis)
stateparametersrange(::Type{PolarizationSPDCBellPhotonsW}) = (
    ηᴬ=(;min=0,max=1,good=1),
    ηᴮ=(;min=0,max=1,good=1),
    N =(;min=0,max=0.2,good=0.01),
)
stateparametersrange(::Type{MultiplexedCascadedBellPhotonsW}) = (
    ηᴬ =(;min=0,max=1,good=1),
    ηᴮ =(;min=0,max=1,good=1),
    ηᶜ¹=(;min=0,max=1,good=1),
    ηᶜ²=(;min=0,max=1,good=1),
    N  =(;min=0,max=0.2,good=0.01),
    Pᵈ =(;min=0,max=1,good=0),
    vis=(;min=0,max=1,good=1),
)
stateparameters(::Type{PolarizationSPDCBellPhotons}) = stateparameters(::Type{PolarizationSPDCBellPhotonsW})
stateparameters(::Type{MultiplexedCascadedBellPhotons}) = stateparameters(::Type{MultiplexedCascadedBellPhotonsW})
stateparametersrange(::Type{PolarizationSPDCBellPhotons}) = stateparametersrange(::Type{PolarizationSPDCBellPhotonsW})
stateparametersrange(::Type{MultiplexedCascadedBellPhotons}) = stateparametersrange(::Type{MultiplexedCascadedBellPhotonsW})
