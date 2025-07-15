module SPDC_HMCS_compilation_module
    using Symbolics: build_function, @variables
    using LinearAlgebra: tr
    @variables eA, eB, eC1, eC2, Ns, Pd, vis
    @variables eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB

    include("dens_mat_SPDC.jl")
    _dens_mat_SPDC_notnorm_expr = _dens_mat_SPDC(eA, eB, Ns)
    _dens_mat_SPDC_tr_expr = tr(_dens_mat_SPDC_notnorm_expr)
    const _dens_mat_SPDC_notnorm! = eval(build_function(_dens_mat_SPDC_notnorm_expr, eA, eB, Ns)[2])
    const _dens_mat_SPDC_tr = eval(build_function(_dens_mat_SPDC_tr_expr, eA, eB, Ns))

    include("dens_mat_HMCS.jl")
    _dens_mat_HMCS_notnorm_expr = _dens_mat_HMCS(eA, eB, eC1, eC2, Ns, Pd, vis)
    _dens_mat_HMCS_tr_expr = tr(_dens_mat_HMCS_notnorm_expr)
    const _dens_mat_HMCS_notnorm! = eval(build_function(_dens_mat_HMCS_notnorm_expr, eA, eB, eC1, eC2, Ns, Pd, vis)[2])
    const _dens_mat_HMCS_tr! = eval(build_function(_dens_mat_HMCS_tr_expr, eA, eB, eC1, eC2, Ns, Pd, vis))

    include("spin_HMCS_elem11.jl")
    include("spin_HMCS_elem22.jl")
    include("spin_HMCS_elem23.jl")
    include("spin_HMCS_elem32.jl")
    include("spin_HMCS_elem33.jl")
    include("spin_HMCS_elem44.jl")
    # XXX We checked whether Symbolics.build_function is faster here -- it was not
    _spin_HMCS_elem11_expr = _spin_HMCS_elem11(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    _spin_HMCS_elem22_expr = _spin_HMCS_elem22(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    _spin_HMCS_elem23_expr = _spin_HMCS_elem23(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    _spin_HMCS_elem32_expr = _spin_HMCS_elem32(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    _spin_HMCS_elem33_expr = _spin_HMCS_elem33(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    _spin_HMCS_elem44_expr = _spin_HMCS_elem44(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
end

"""SPDC based Polarization Entanglement generation source -- two-photon Fock space cutoff"""
function _dens_mat_SPDC(eA, eB, Ns) # TODO use a sparse matrix
    ρ = zeros(ComplexF64, (81, 81))
    SPDC_HMCS_compilation_module._dens_mat_SPDC_notnorm!(ρ, eA, eB, Ns)
    return ρ
end

"""heralded multiplexed cascaded source (a.k.a. single mode model for zero added loss multiplexed (ZALM) source) -- two-photon Fock space cutoff"""
function _dens_mat_HMCS(eA, eB, eC1, eC2, Ns, Pd, vis) # TODO use a sparse matrix
    ρ = zeros(ComplexF64, (81, 81))
    SPDC_HMCS_compilation_module._dens_mat_HMCS_notnorm!(ρ, eA, eB, eC1, eC2, Ns, Pd, vis)
    return ρ
end

"""heralded multiplexed cascaded source after swapped with emissive spin memories"""
function _dens_mat_spin_HMCS(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    ρ = zeros(ComplexF64, (4, 4)) # TODO make this a sparse matrix
    ρ[1,1] = SPDC_HMCS_compilation_module._spin_HMCS_elem11(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    ρ[2,2] = SPDC_HMCS_compilation_module._spin_HMCS_elem22(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    ρ[2,3] = SPDC_HMCS_compilation_module._spin_HMCS_elem23(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    ρ[3,2] = SPDC_HMCS_compilation_module._spin_HMCS_elem32(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    ρ[3,3] = SPDC_HMCS_compilation_module._spin_HMCS_elem33(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
    ρ[4,4] = SPDC_HMCS_compilation_module._spin_HMCS_elem44(eAm, eBm, eAs, eBs, eC1, eC2, Ns, Pd, Pdo1, Pdo2, vis, gA, gB)
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
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the 2-photon cutoff of the Fock space used in derivation)"""
    N
end
"""The normalized version of [`PolarizationSPDCBellPhotonsW`](@ref)."""
@withmetadata struct PolarizationSPDCBellPhotons # TODO <: AbstractTwoQubitState
    spdc::PolarizationSPDCBellPhotonsW
end
PolarizationSPDCBellPhotons(ηᴬ, ηᴮ, N) = PolarizationSPDCBellPhotons(PolarizationSPDCBellPhotonsW(ηᴬ, ηᴮ, N))

"""
$TYPEDEF

Fields:

$FIELDS

Heralded multiplexed cascaded source (a.k.a. single mode model for zero added loss multiplexed (ZALM) source).
The two modes each live in Fock spaces of n≤2 photons (the model does not track higher excitations).
The state is not normalized and its trace corresponds to the probability of successful heralding.
"""
@withmetadata struct MultiplexedCascadedBellPhotonsW
    """Outcoupling transmissivity on Alice’s side (or signal), ∈[0,1]"""
    ηᴬ
    """Outcoupling transmissivity on Bob’s side (or idler), ∈[0,1]"""
    ηᴮ
    """Coupling from SPDC source 1 to linear optical BSM (implicitly must account for detection efficiency)"""
    ηᶜ¹
    """Coupling from SPDC source 2 to linear optical BSM (implicitly must account for detection efficiency)"""
    ηᶜ²
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the 2-photon cutoff of the Fock space used in derivation)"""
    N
    """Total excess noise (photons per qubit slot) in photon detectors, ≥0, usually ≪1"""
    Pᵈ
    """Swap visibility product, ∈[0,1]"""
    vis
end
"""The normalized version of [`MultiplexedCascadedBellPhotonsW`](@ref)."""
@withmetadata struct MultiplexedCascadedBellPhotons
    hmcs::MultiplexedCascadedBellPhotonsW
end
MultiplexedCascadedBellPhotons(ηᴬ, ηᴮ, ηᶜ¹, ηᶜ², N, Pᵈ, vis) = MultiplexedCascadedBellPhotons(MultiplexedCascadedBellPhotonsW(ηᴬ, ηᴮ, ηᶜ¹, ηᶜ², N, Pᵈ, vis))

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
stateparameters(::Type{PolarizationSPDCBellPhotons}) = stateparameters(PolarizationSPDCBellPhotonsW)
stateparameters(::Type{MultiplexedCascadedBellPhotons}) = stateparameters(MultiplexedCascadedBellPhotonsW)
stateparametersrange(::Type{PolarizationSPDCBellPhotons}) = stateparametersrange(PolarizationSPDCBellPhotonsW)
stateparametersrange(::Type{MultiplexedCascadedBellPhotons}) = stateparametersrange(MultiplexedCascadedBellPhotonsW)

# TODO implement express for PolarizationSPDCBellPhotons and MultiplexedCascadedBellPhotons

"""
$TYPEDEF

Fields:

$FIELDS

Heralded multiplexed cascaded source (a.k.a. single mode model for zero added loss multiplexed (ZALM) source),
after a swap with spin-½ memories.

The state is not normalized and its trace corresponds to the probability of successful heralding.

Based on the cascaded source from [prajit2022heralded](@cite) and [kevin2023zero](@cite)
after being stored in spin memories as discussed in [prajit2023entangling](@cite).
"""
@withmetadata struct MultiplexedCascadedBellPairW <: AbstractTwoQubitState
    """Outcoupling transmissivity of photon from Alice’s spin memory, ∈[0,1]"""
    ηᴬᵐ
    """Outcoupling transmissivity of photon from on Bob’s spin memory, ∈[0,1]"""
    ηᴮᵐ
    """Outcoupling transmissivity on Alice’s side of HMCS (or signal), ∈[0,1]"""
    ηᴬˢ
    """Outcoupling transmissivity on Bob’s side of HMCS (or idler), ∈[0,1]"""
    ηᴮˢ
    """Coupling from SPDC source 1 to linear optical BSM (implicitly must account for detection efficiency)"""
    ηᶜ¹
    """Coupling from SPDC source 2 to linear optical BSM (implicitly must account for detection efficiency)"""
    ηᶜ²
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the 2-photon cutoff of the Fock space used in derivation)"""
    N
    """Excess noise (photons per qubit slot) in photon detectors for swap of HMCS, ≥0, usually ≪1"""
    Pᵈ
    """Excess noise (photons per qubit slot) in photon detectors for swap on Alice's side, ≥0, usually ≪1"""
    Pᴬᵈ
    """Excess noise (photons per qubit slot) in photon detectors for swap on Bob's side, ≥0, usually ≪1"""
    Pᴮᵈ
    """Swap visibility product, ∈[0,1]"""
    vis
    """Spin qubit initialization parameter on Alice's side, ∈[0,1], usually =½"""
    gᴬ
    """Spin qubit initialization parameter on Bob's side, ∈[0,1], usually =½"""
    gᴮ
end
"""The normalized version of [`MultiplexedCascadedBellPairW`](@ref)."""
@withmetadata struct MultiplexedCascadedBellPair <: AbstractTwoQubitState
    hmcs::MultiplexedCascadedBellPairW
end
MultiplexedCascadedBellPair(ηᴬᵐ, ηᴮᵐ, ηᴬˢ, ηᴮˢ, ηᶜ¹, ηᶜ², N, Pᵈ, Pᴬᵈ, Pᴮᵈ, vis, gᴬ, gᴮ) = MultiplexedCascadedBellPair(MultiplexedCascadedBellPairW(ηᴬᵐ, ηᴮᵐ, ηᴬˢ, ηᴮˢ, ηᶜ¹, ηᶜ², N, Pᵈ, Pᴬᵈ, Pᴮᵈ, vis, gᴬ, gᴮ))
"Symmetric noiseless perfectly mode-matched well-initialized case ηᵐ=ηᴬᵐ=ηᴮᵐ, ηˢ=ηᴬˢ=ηᴮˢ, ηᶜ=ηᶜ¹=ηᶜ², Pᵈ=Pᴬᵈ=Pᴮᵈ, vis=1, gᴬ=gᴮ=½"
MultiplexedCascadedBellPairW(ηᵐ, ηˢ, ηᶜ, N) = MultiplexedCascadedBellPairW(ηᵐ, ηᵐ, ηˢ, ηˢ, ηᶜ, ηᶜ, N, 0, 0, 0, 1, 0.5, 0.5)
MultiplexedCascadedBellPair(ηᵐ, ηˢ, ηᶜ, N) = MultiplexedCascadedBellPair(ηᵐ, ηᵐ, ηˢ, ηˢ, ηᶜ, ηᶜ, N, 0, 0, 0, 1, 0.5, 0.5)

stateparameters(::Type{MultiplexedCascadedBellPairW}) = (:ηᴬᵐ, :ηᴮᵐ, :ηᴬˢ, :ηᴮˢ, :ηᶜ¹, :ηᶜ², :N, :Pᵈ, :Pᴬᵈ, :Pᴮᵈ, :vis, :gᴬ, :gᴮ)
stateparametersrange(::Type{MultiplexedCascadedBellPairW}) = (
    ηᴬᵐ =(;min=0,max=1,good=1),
    ηᴮᵐ =(;min=0,max=1,good=1),
    ηᴬˢ =(;min=0,max=1,good=1),
    ηᴮˢ =(;min=0,max=1,good=1),
    ηᶜ¹ =(;min=0,max=1,good=1),
    ηᶜ² =(;min=0,max=1,good=1),
    N   =(;min=0,max=0.2,good=0.01),
    Pᵈ  =(;min=0,max=0.1,good=0),
    Pᴬᵈ =(;min=0,max=0.1,good=0),
    Pᴮᵈ =(;min=0,max=0.1,good=0),
    vis =(;min=0,max=1,good=1),
    gᴬ =(;min=0,max=1,good=0.5),
    gᴮ =(;min=0,max=1,good=0.5),
)
stateparameters(::Type{MultiplexedCascadedBellPair}) = stateparameters(MultiplexedCascadedBellPairW)
stateparametersrange(::Type{MultiplexedCascadedBellPair}) = stateparametersrange(MultiplexedCascadedBellPairW)

function express_nolookup(x::MultiplexedCascadedBellPairW, ::QuantumOpticsRepr)
    (;ηᴬᵐ, ηᴮᵐ, ηᴬˢ, ηᴮˢ, ηᶜ¹, ηᶜ², N, Pᵈ, Pᴬᵈ, Pᴮᵈ, vis, gᴬ, gᴮ) = x
    mat = _dens_mat_spin_HMCS(ηᴬᵐ, ηᴮᵐ, ηᴬˢ, ηᴮˢ, ηᶜ¹, ηᶜ², N, Pᵈ, Pᴬᵈ, Pᴮᵈ, vis, gᴬ, gᴮ)
    return SparseOperator(_bspin⊗_bspin, mat)
end

function express_nolookup(x::MultiplexedCascadedBellPair, ::QuantumOpticsRepr)
    op = express(x.hmcs, QuantumOpticsRepr())
    op ./= tr(op)
    return op
end

tr(::MultiplexedCascadedBellPair) = 1
tr(x::MultiplexedCascadedBellPairW) = tr(express(x, QuantumOpticsRepr()))

symbollabel(x::MultiplexedCascadedBellPair) = "ρᶻᵃˡᵐ"
symbollabel(x::MultiplexedCascadedBellPairW) = "ρ′ᶻᵃˡᵐ"
