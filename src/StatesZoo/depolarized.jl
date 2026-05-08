"""
$TYPEDEF

Fields:

$FIELDS

A symbolic representation of the depolarized |Φ⁺⟩ = (|00⟩+|11⟩)/√2 Bell state:
`p |Φ⁺⟩⟨Φ⁺| + (1-p) I/4`

where `I/4` is the two-qubit maximally mixed state.

The fidelity `F = ⟨Φ⁺|ρ|Φ⁺⟩` relates to the depolarization parameter by:
- `F = (3p + 1) / 4`
- `p = (4F - 1) / 3`

Can be constructed from either parameter:
- `DepolarizedBellPair(p)` — depolarization parameter `p ∈ [0, 1]`
- `DepolarizedBellPair(F=F)` — from fidelity `F ∈ [1/4, 1]`
"""
@withmetadata struct DepolarizedBellPair <: AbstractTwoQubitState
    """Depolarization parameter `p ∈ [0, 1]`, related to fidelity by `F = (3p+1)/4`"""
    p
end

DepolarizedBellPair(; F) = DepolarizedBellPair((4 * F - 1) / 3)

stateparameters(::Type{DepolarizedBellPair}) = (:p,)
stateparametersrange(::Type{DepolarizedBellPair}) = (p=(;min=0,max=1,good=1),)

symbollabel(x::DepolarizedBellPair) = "ρᵖ"

function express_nolookup(x::DepolarizedBellPair, r::QuantumOpticsRepr)
    pure_dm = SProjector((Z1⊗Z1 + Z2⊗Z2) / sqrt(2))
    mixed_dm = MixedState(pure_dm)
    return express(x.p*pure_dm + (1-x.p)*mixed_dm, r)
end

function express_nolookup(x::DepolarizedBellPair, r::CliffordRepr)
    pure_dm = SProjector(StabilizerState("ZZ XX"))
    mixed_dm = MixedState(StabilizerState("ZZ XX"))
    return express(x.p * pure_dm + (1 - x.p) * mixed_dm, r)
end
