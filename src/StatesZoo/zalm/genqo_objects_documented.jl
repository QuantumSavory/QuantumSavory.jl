"""
Questions for Stefan:
    - Is there an alternative to "MultiplexedCascadedBellPairW <: AbstractTwoQubitState" since we can also consider the photon-photon state?
    - I have databases of states that were previously calculated. Is it possible for the visualization functions to use these as an alternative to calculating the state every time?
"""

using CondaPkg
using PythonCall
import LinearAlgebra: tr

##

CondaPkg.add_pip("genqo")

##

gq = pyimport("genqo")

##

"""
$TYPEDEF

Fields:

$FIELDS

Heralded multiplexed cascaded source (a.k.a. single mode model for zero added loss multiplexed (ZALM) source).

The state is not normalized and its trace corresponds to the probability of successful heralding.

Based on the cascaded source from [prajit2022heralded](@cite) and [kevin2023zero](@cite).

Functions are included for both the photon-photon state as well as the spin-spin state following loading using Duan-Kimble style quantum memories

"""

@withmetadata struct MultiplexedCascadedBellPairW <: AbstractTwoQubitState
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

stateparameters(::Type{MultiplexedCascadedBellPairW}) = (:ηᵇ, :ηᵈ, :ηᵗ, :N, :Pᵈ)
stateparametersrange(::Type{MultiplexedCascadedBellPairW}) = (
    ηᵇ =(;min=0,max=1,good=1),
    ηᵈ =(;min=0,max=1,good=1),
    ηᵗ =(;min=0,max=1,good=1),
    N   =(;min=0,max=10,good=0.1),
    Pᵈ  =(;min=0,max=0.1,good=10^(-8))
)

function _express_photon_photon_probability_of_generation(x::MultiplexedCascadedBellPairW)
    # This function calculates the photon-photon probability of generation
    (;ηᵇ, ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.ZALM()
    state.params["bsm_efficiency"] = ηᵇ
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_probability_success()
    return state.results["probability_success"]
end

function _express_photon_photon_fidelity(x::MultiplexedCascadedBellPairW)
    # This function calculates the photon-photon fidelity
    (;ηᵇ, ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.ZALM()
    state.params["bsm_efficiency"] = ηᵇ
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_fidelity()
    return state.results["fidelity"]
end

function _express_spin_spin_matrix(x::MultiplexedCascadedBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    (;ηᵇ, ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.ZALM()
    state.params["bsm_efficiency"] = ηᵇ
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_density_operator(np.array([1,0,1,1,0,0,1,0]))
    return state.results["output_state"]
end

function _express_spin_spin_probability_of_generation(x::MultiplexedCascadedBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    (;ηᵇ, ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.ZALM()
    state.params["bsm_efficiency"] = ηᵇ
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_density_operator(np.array([1,0,1,1,0,0,1,0]))
    return tr(state.results["output_state"])
end

function _express_spin_spin_fidelity(x::MultiplexedCascadedBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    (;ηᵇ, ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.ZALM()
    state.params["bsm_efficiency"] = ηᵇ
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_density_operator(np.array([1,0,1,1,0,0,1,0]))
    rho_un = state.results["output_state"]
    Ps =  tr(rho_un)
    return (1/2)*(rho_un[0][0] - rho_un[0][3] - rho_un[3][0] + rho_un[3][3])/(Ps)
end


"""

SPDC source

These functions are for an unheralded source of polarization bell pairs, as described by Kwiat et al (Phys. Rev. Lett. 75, 4337 (1995))

Functions are included for both the photon-photon state as well as the spin-spin state following loading using Duan-Kimble style quantum memories

"""

@withmetadata struct UnheraldedSPDCBellPairW <: AbstractTwoQubitState
    """Loss (transmissivity) in all of the detectors, ∈[0,1]"""
    ηᵈ
    """Outcoupling transmissivity for the bell-state modes (1,2,3,4), ∈[0,1]"""
    ηᵗ
    """Mean photon number per mode of the state. This is a tradeoff parameter for fidelity vs rate. It has to be >0 (but the model becomes imprecise at N>0.2 due to the 2-photon cutoff of the Fock space used in derivation)"""
    N
    """Excess noise (photons per qubit slot) in photon detectors, ≥0, usually ≪1"""
    Pᵈ
end

stateparameters(::Type{UnheraldedSPDCBellPairW}) = (:ηᵈ, :ηᵗ, :N, :Pᵈ)
stateparametersrange(::Type{UnheraldedSPDCBellPairW}) = (
    ηᵈ =(;min=0,max=1,good=1),
    ηᵗ =(;min=0,max=1,good=1),
    N   =(;min=0,max=10,good=0.1),
    Pᵈ  =(;min=0,max=0.1,good=10^(-6))
)

function _express_photon_photon_probability_of_generation(x::UnheraldedSPDCBellPairW)
    # This function calculates the photon-photon probability of generation
    (;ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.SPDC()
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_probability_success()
    return state.results["probability_success"]
end

function _express_photon_photon_fidelity(x::UnheraldedSPDCBellPairW)
    # This function calculates the photon-photon fidelity
    (;ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.SPDC()
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_fidelity()
    return state.results["fidelity"]
end

function _express_spin_spin_matrix(x::UnheraldedSPDCBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    (;ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.SPDC()
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_density_operator(np.array([0,1,0,1]))
    return state.results["output_state"]
end

function _express_spin_spin_probability_of_generation(x::UnheraldedSPDCBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    (;ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.SPDC()
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_density_operator(np.array([0,1,0,1]))
    return tr(state.results["output_state"])
end

function _express_spin_spin_fidelity(x::UnheraldedSPDCBellPairW)
    # This function calculates the unnormalized spin-spin density matrix
    (;ηᵈ, ηᵗ, N, Pᵈ) = x

    state = gq.SPDC()
    state.params["outcoupling_efficiency"] = ηᵗ
    state.params["detection_efficiency"] = ηᵈ
    state.params["dark_counts"] = Pᵈ
    state.params["mean_photon"] = N
    state.run()
    state.calculate_density_operator(np.array([0,1,0,1]))
    rho_un = state.results["output_state"]
    Ps =  tr(rho_un)
    return (1/2)*(rho_un[0][0] - rho_un[0][3] - rho_un[3][0] + rho_un[3][3])/(Ps)
end


