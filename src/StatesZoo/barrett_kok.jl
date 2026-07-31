"""
$TYPEDEF

Fields:

$FIELDS

A symbolic representation of the noisy Bell pair state
obtained in a Barrett-Kok style protocol
(a sequence of two successful entanglement swaps),
referred to as the "dual rail photonic qubit swap"
in [prajit2023entangling](@cite) (see eq. C7).

See also [`BarrettKokBellPairW`](@ref) for the weighted density matrix.
"""
@withmetadata struct BarrettKokBellPair <: AbstractTwoQubitState
    """Individual channel transmissivity from source A to entanglement swapping station, ∈[0,1]"""
    ηᴬ
    """Individual channel transmissivity from source B to entanglement swapping station, ∈[0,1]"""
    ηᴮ
    """Total excess noise (photons per qubit slot) in photon detectors, ≥0, usually ≪1 """
    Pᵈ
    """Detection efficiency of photon detectors, ∈[0,1]"""
    ηᵈ
    """Mode matching parameter for individual interacting photonic pulses with `|V|` evaluates mode overlap and `arg(V)` evaluates the carrier phase mismatch, |V|∈[0,1]"""
    𝒱
    """A single parity bit determined by the click pattern (m = 0 for [0, 1, 1, 0] or [1, 0, 0, 1]; m = 1 for [1, 1, 0, 0] or [0, 0, 1, 1])"""
    m
end

"""The weighted version of [`BarrettKokBellPair`](@ref), i.e. its trace is the probability of successfully heralding a Barrett-Kok Bell pair."""
@withmetadata struct BarrettKokBellPairW <: AbstractTwoQubitState
    bkbp::BarrettKokBellPair
end

symbollabel(x::BarrettKokBellPair) = "ρᴮᴷ"
symbollabel(x::BarrettKokBellPairW) = "ρ′ᴮᴷ"

"""    BarrettKokBellPair(η)
Symmetric noiseless perfectly mode-matched case ηᴬ=ηᴮ=η, Pᵈ=0, ηᵈ=1, 𝒱=1, m=0"""
BarrettKokBellPair(η) = BarrettKokBellPair(η, η, 0, 1, 1, 0)
"""    BarrettKokBellPair(ηᴬ,ηᴮ)
Asymmetric noiseless perfectly mode-matched case ηᴬ≠ηᴮ, Pᵈ=0, ηᵈ=1, 𝒱=1, m=0"""
BarrettKokBellPair(ηᴬ,ηᴮ) = BarrettKokBellPair(ηᴬ, ηᴮ, 0, 1, 1, 0)
BarrettKokBellPair(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱) = BarrettKokBellPair(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, 0)

BarrettKokBellPairW(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, m=0) = BarrettKokBellPairW(BarrettKokBellPair(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, m))
BarrettKokBellPairW(η::Number) = BarrettKokBellPairW(BarrettKokBellPair(η))
BarrettKokBellPairW(ηᴬ,ηᴮ) = BarrettKokBellPairW(BarrettKokBellPair(ηᴬ,ηᴮ))

function _express_bk(x::BarrettKokBellPair)
    (; ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, m) = x

    d₁⁽⁰⁾ = d₂⁽⁰⁾ = ηᴬ * ηᴮ * ηᵈ^2 / 4 # eq C8
    d₃⁽⁰⁾ = d₁⁽⁰⁾ * abs2(𝒱) * (-1)^m # eq C8
    d₁⁽¹⁾ = (1-Pᵈ) * ηᵈ * (ηᴬ+ηᴮ-2*ηᴬ*ηᴮ*ηᵈ) + Pᵈ*(1-ηᴬ*ηᵈ)*(1-ηᴮ*ηᵈ)  # eq C9
    Nᵈ = 2 * (1-Pᵈ)^4 * d₁⁽⁰⁾ + 4 * Pᵈ * (1-Pᵈ)^2 * d₁⁽¹⁾ # eq C7

    p00 = projector(L₀⊗L₀)
    p01 = projector(L₀⊗L₁)
    p10 = projector(L₁⊗L₀)
    p11 = projector(L₁⊗L₁)
    off01 = (L₀⊗L₁)*dagger(L₁⊗L0)

    A = d₁⁽⁰⁾ * (p01+p10) + d₃⁽⁰⁾ * (off01 + dagger(off01))
    B = d₁⁽¹⁾ * I⊗I

    sym_expression = ((1-Pᵈ)^4 * A + Pᵈ*(1-Pᵈ)^2 * B) # Make that available as well through an appropriate function

    return sym_expression, Nᵈ
end

function express_nolookup(x::BarrettKokBellPair, ::QuantumOpticsRepr)
    sym_expression, Nᵈ = _express_bk(x)
    return express(sym_expression/Nᵈ, QuantumOpticsRepr())
end

function express_nolookup(x::BarrettKokBellPairW, ::QuantumOpticsRepr)
    sym_expression, Nᵈ = _express_bk(x.bkbp)
    return express(sym_expression, QuantumOpticsRepr())
end

## Symbolic trace
tr(::BarrettKokBellPair) = 1
tr(x::BarrettKokBellPairW) = _express_bk(x.bkbp)[2]
