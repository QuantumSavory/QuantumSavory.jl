function midswap_single_rail(eA,eB,gA,gB,Pd,Vis)
    m11=gA*gB*(1-Pd)*Pd
    m22=(1/2)*eB*gA*(1-gB)*(1-Pd)^2+(1-eB)*gA*(1-gB)*(1-Pd)*Pd

    m33=(1/2)*eA*(1-gA)*gB*(1-Pd)^2+(1-eA)*(1-gA)*gB*(1-Pd)*Pd

    m23=(Vis)*(1/2)*((eA*eB*(1-gA)*gA*(1-gB)*gB)^(1/2))*(1-Pd)^2

    m32=(Vis)*(1/2)*((eA*eB*(1-gA)*gA*(1-gB)*gB)^(1/2))*(1-Pd)^2
    
    m44=((1/2)*eB*(1-eA)*(1-gA)*(1-gB)+(1/2)*eA*(1-eB)*(1-gA)*(1-gB))*(1-Pd)^2+(1-eA)*(1-eB)*(1-gA)*(1-gB)*(1-Pd)*Pd

    return [m11 0 0 0 ; 0 m22 m23 0 ; 0 m32 m33 0 ; 0 0 0 m44]
end

function midswap_dual_rail(eA,eB,gA,gB,Pd,Vis)
    m11=((1/2)*eA*(1+(-1)*eB)*gA*gB+(1/2)*(1+(-1)*eA)*eB*gA*gB)*(1+(-1)*Pd)^3*Pd+(1+(-1)*eA)*(1+(-1)*eB)*gA*gB*(1+(-1)*Pd)^2*Pd^2

    m22=(1/4)*eA*eB*gA*(1+(-1)*gB)*(1+(-1)*Pd)^4+(1/2)*eA*(1+(-1)*eB)*gA*(1+(-1)*gB)*(1+(-1)*Pd)^3*Pd+(1/2)*(1+(-1)*eA)*eB*gA*(1+(-1)*gB)*(1+(-1)*Pd)^3*Pd+(1+(-1)*eA)*(1+(-1)*eB)*gA*(1+(-1)*gB)*(1+(-1)*Pd)^2*Pd^2

    m33=(1/4)*eA*eB*(1+(-1)*gA)*gB*(1+(-1)*Pd)^4+(1/2)*eA*(1+(-1)*eB)*(1+(-1)*gA)*gB*(1+(-1)*Pd)^3*Pd+(1/2)*(1+(-1)*eA)*eB*(1+(-1)*gA)*gB*(1+(-1)*Pd)^3*Pd+(1+(-1)*eA)*(1+(-1)*eB)*(1+(-1)*gA)*gB*(1+(-1)*Pd)^2*Pd^2

    m44=((1/2)*eA*(1+(-1)*eB)*(1+(-1)*gA)*(1+(-1)*gB)+(1/2)*(1+(-1)*eA)*eB*(1+(-1)*gA)*(1+(-1)*gB))*(1+(-1)*Pd)^3*Pd+(1+(-1)*eA)*(1+(-1)*eB)*(1+(-1)*gA)*(1+(-1)*gB)*(1+(-1)*Pd)^2*Pd^2

    m23=(Vis^2)*(1/4)*eA*eB*(1+(-1)*gA)^(1/2)*gA^(1/2)*(1+(-1)*gB)^(1/2)*gB^(1/2)*(1+(-1)*Pd)^4

    return [m11 0 0 0 ; 0 m22 m23 0 ; 0 m23' m33 0 ; 0 0 0 m44]
end

"""
$TYPEDEF

Fields:

$FIELDS

Generates the unnormalized spin-spin density matrix for linear photonic entanglement swap 
with emissive memories emitting single rail photonic qubits from the paper [prajit2023entangling](@cite).
Since the matrix is 'weighted' by the probability for success, it is suffixed with a W to distinguish it 
from the normalized object `SingleRailMidSwapBell`.

```jldoctest
julia> using QuantumSavory.StatesZoo: SingleRailMidSwapBellW

julia> r = Register(2);

julia> initialize!(r[1:2], SingleRailMidSwapBellW(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99));

julia> observable(r[1:2], Z⊗Z)
-0.202499993925 + 0.0im
```
"""
@withmetadata struct SingleRailMidSwapBellW <: AbstractTwoQubitState
    "Link efficiencies for memory A upto the swap (include link loss, detector efficiency, etc.)"
    eA::Float64
    "Link efficiencies for memory B upto the swap (include link loss, detector efficiency, etc.)"
    eB::Float64
    "Memory initialization parameter for memory A"
    gA::Float64
    "Memory initialization parameter for memory B"
    gB::Float64
    "Detector dark count probability per photonic mode (assumed to be the same for both detectors)"
    Pd::Float64
    "Interferometer visibility for the midpoint swap' can be complex to account for phase instability"
    Vis::Float64
end

symbollabel(x::SingleRailMidSwapBellW) = "ρˢʳᵐˢᵂ"


"""
$TYPEDEF

Fields:

$FIELDS

Generates the normalized spin-spin density matrix for linear photonic entanglement swap 
with emissive memories emitting single rail photonic qubits from the paper [prajit2023entangling](@cite)

```jldoctest
julia> using QuantumSavory.StatesZoo: SingleRailMidSwapBell

julia> r = Register(2);

julia> initialize!(r[1:2], SingleRailMidSwapBell(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99));

julia> observable(r[1:2], Z⊗Z)
-0.8181818000000001 + 0.0im
```
"""
@withmetadata struct SingleRailMidSwapBell <: AbstractTwoQubitState
    "Link efficiencies for memory A upto the swap (include link loss, detector efficiency, etc.)"
    eA::Float64
    "Link efficiencies for memory B upto the swap (include link loss, detector efficiency, etc.)"
    eB::Float64
    "Memory initialization parameter for memory A"
    gA::Float64
    "Memory initialization parameter for memory B"
    gB::Float64
    "Detector dark count probability per photonic mode (assumed to be the same for both detectors)"
    Pd::Float64
    "Interferometer visibility for the midpoint swap' can be complex to account for phase instability"
    Vis::Float64
end

symbollabel(x::SingleRailMidSwapBell) = "ρˢʳᵐˢ"


"""
$TYPEDEF

Fields:

$FIELDS

Generates the unnormalized spin-spin density matrix for linear photonic entanglement swap with emissive
 memories emitting dual rail photonic qubits from the paper [prajit2023entangling](@cite). 
 Since the matrix is 'weighted' by the probability for success, it is suffixed with a W to distinguish it 
from the normalized object `DualRailMidSwapBell`.

```jldoctest
julia> using QuantumSavory.StatesZoo: DualRailMidSwapBellW

julia> r = Register(2);

julia> initialize!(r[1:2], DualRailMidSwapBellW(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99));

julia> observable(r[1:2], Z⊗Z)
-0.10124999595000005 + 0.0im
```
"""
@withmetadata struct DualRailMidSwapBellW <: AbstractTwoQubitState
    "Link efficiencies for memory A upto the swap (include link loss, detector efficiency, etc.)"
    eA::Float64
    "Link efficiencies for memory B upto the swap (include link loss, detector efficiency, etc.)"
    eB::Float64
    "Memory initialization parameter for memory A"
    gA::Float64
    "Memory initialization parameter for memory B"
    gB::Float64
    "Detector dark count probability per photonic mode (assumed to be the same for both detectors)"
    Pd::Float64
    "Interferometer visibility for the midpoint swap"
    Vis::Float64
end

symbollabel(x::DualRailMidSwapBellW) = "ρᵈʳᵐˢᵂ"


"""
$TYPEDEF

Fields:

$FIELDS

Generates the normalized spin-spin density matrix for linear photonic entanglement swap with emissive
 memories emitting dual rail photonic qubits from the paper [prajit2023entangling](@cite).

```jldoctest
julia> using QuantumSavory.StatesZoo: DualRailMidSwapBell

julia> r = Register(2);

julia> initialize!(r[1:2], DualRailMidSwapBell(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99));

julia> observable(r[1:2], Z⊗Z)
-0.9999999911111113 + 0.0im
```
"""
@withmetadata struct DualRailMidSwapBell <: AbstractTwoQubitState
    "Link efficiencies for memory A upto the swap (include link loss, detector efficiency, etc.)"
    eA::Float64
    "Link efficiencies for memory B upto the swap (include link loss, detector efficiency, etc.)"
    eB::Float64
    "Memory initialization parameter for memory A"
    gA::Float64
    "Memory initialization parameter for memory B"
    gB::Float64
    "Detector dark count probability per photonic mode (assumed to be the same for both detectors)"
    Pd::Float64
    "Interferometer visibility for the midpoint swap"
    Vis::Float64
end

symbollabel(x::DualRailMidSwapBell) = "ρᵈʳᵐˢ"


## express

function express_nolookup(x::SingleRailMidSwapBellW, ::QuantumOpticsRepr)
    data = midswap_single_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data))
end

function express_nolookup(x::SingleRailMidSwapBell, ::QuantumOpticsRepr)
    data = midswap_single_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data/tr(data)))
end

function express_nolookup(x::DualRailMidSwapBellW, ::QuantumOpticsRepr)
    data = midswap_dual_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data))
end

function express_nolookup(x::DualRailMidSwapBell, ::QuantumOpticsRepr)
    data = midswap_dual_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data/tr(data)))
end

# Symbolic trace

tr(::SingleRailMidSwapBell) = 1
tr(::DualRailMidSwapBell) = 1