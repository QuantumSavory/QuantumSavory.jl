"""
$TYPEDEF

Fields:

$FIELDS

A symbolic representation of a depolarized pure state:
`p |ψ⟩⟨ψ| + (1-p) I/d`

where `|ψ⟩` is an arbitrary pure two-qubit state (default: |Φ⁺⟩ = (|00⟩+|11⟩)/√2),
and `I/d` is the maximally mixed state in the same Hilbert space.

The fidelity `F = ⟨ψ|ρ|ψ⟩` with respect to `|ψ⟩` relates to the depolarization parameter by:
- `F = (3p + 1) / 4`
- `p = (4F - 1) / 3`

Can be constructed from either parameter:
- `DepolarizedBellPair(p)` — depolarization parameter `p ∈ [0, 1]`, defaults to |Φ⁺⟩
- `DepolarizedBellPair(p, pure_state)` — with a custom pure state
- `DepolarizedBellPair(F=F)` — from fidelity `F ∈ [1/4, 1]`, defaults to |Φ⁺⟩
- `DepolarizedBellPair(F=F, pure_state=s)` — from fidelity with a custom pure state
"""
@withmetadata struct DepolarizedBellPair <: AbstractTwoQubitState
    """Depolarization parameter `p ∈ [0, 1]`, related to fidelity by `F = (3p+1)/4`"""
    p
    """The ideal pure state being depolarized (default: |Φ⁺⟩)"""
    pure_state
end

const _depolarized_default_bell = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)

DepolarizedBellPair(p) = DepolarizedBellPair(p, _depolarized_default_bell)
DepolarizedBellPair(; F, pure_state=_depolarized_default_bell) = DepolarizedBellPair((4 * F - 1) / 3, pure_state)

stateparameters(::Type{DepolarizedBellPair}) = (:p,)
stateparametersrange(::Type{DepolarizedBellPair}) = (p=(;min=0,max=1,good=1),)

symbollabel(x::DepolarizedBellPair) = "ρᵖ"

function express_nolookup(x::DepolarizedBellPair, r::QuantumOpticsRepr)
    (; p, pure_state) = x
    pure_dm = SProjector(pure_state)
    mixed_dm = MixedState(pure_dm)
    return express(p*pure_dm + (1-p)*mixed_dm, r)
end
