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
with emissive memories emitting single rail photonic qubits from the paper [prajit2023entangling](@cite)
It takes the following parameters:
- eA, eB: Link efficiencies for memories A and B upto the swap (include link loss, detector efficiency, etc.)
- gA, gB: Memory initialization parameter for memories A and B
- Pd: Detector dark count probability per photonic mode (assumed to be the same for both detectors)
- Vis: Interferometer visibility for the midpoint swap' can be complex to account for phase instability

```jldoctest
julia> r = Register(2)

julia> initialize!(r[1:2], SingleRailMidSwapBellU(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99))

julia> observable(r[1:2], Z⊗Z)
```
"""
@withmetadata struct SingleRailMidSwapBellU <: AbstractTwoQubitState
    eA::Float64
    eB::Float64
    gA::Float64
    gB::Float64
    Pd::Float64
    Vis::Float64
end

symbollabel(x::SingleRailMidSwapBellU) = "ρˢʳᵐˢᵁ"


"""
$TYPEDEF

Fields:

$FIELDS

Generates the normalized spin-spin density matrix for linear photonic entanglement swap 
with emissive memories emitting single rail photonic qubits from the paper [prajit2023entangling](@cite)
It takes the following parameters:
- eA, eB: Link efficiencies for memories A and B upto the swap (include link loss, detector efficiency, etc.)
- gA, gB: Memory initialization parameter for memories A and B
- Pd: Detector dark count probability per photonic mode (assumed to be the same for both detectors)
- Vis: Interferometer visibility for the midpoint swap' can be complex to account for phase instability

```jldoctest
julia> r = Register(2)

julia> initialize!(r[1:2], SingleRailMidSwapBellN(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99))

julia> observable(r[1:2], Z⊗Z)
```
"""
@withmetadata struct SingleRailMidSwapBellN <: AbstractTwoQubitState
    eA::Float64
    eB::Float64
    gA::Float64
    gB::Float64
    Pd::Float64
    Vis::Float64
end

symbollabel(x::SingleRailMidSwapBellN) = "ρˢʳᵐˢᴺ"


"""
$TYPEDEF

Fields:

$FIELDS

Generates the unnormalized spin-spin density matrix for linear photonic entanglement swap with emissive
 memories emitting dual rail photonic qubits from the paper [prajit2023entangling](@cite).
 It takes the following parameters:
 - eA, eB: Link efficiencies for memories A and B upto the swap (include link loss, detector efficiency, etc.)
- gA, gB: Memory initialization parameter for memories A and B 
- Pd: Detector dark count probability per photonic mode (assumed to be the same for both detectors)
- Vis: Interferometer visibility for the midpoint swap 

```jldoctest
julia> r = Register(2)

julia> initialize!(r[1:2], DualRailMidSwapBellU(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99))

julia> observable(r[1:2], Z⊗Z)
```
"""
@withmetadata struct DualRailMidSwapBellU <: AbstractTwoQubitState
    eA::Float64
    eB::Float64
    gA::Float64
    gB::Float64
    Pd::Float64
    Vis::Float64
end

symbollabel(x::DualRailMidSwapBellU) = "ρᵈʳᵐˢᵁ"


"""
$TYPEDEF

Fields:

$FIELDS

Generates the normalized spin-spin density matrix for linear photonic entanglement swap with emissive
 memories emitting dual rail photonic qubits from the paper [prajit2023entangling](@cite).
 It takes the following parameters:
 - eA, eB: Link efficiencies for memories A and B upto the swap (include link loss, detector efficiency, etc.)
- gA, gB: Memory initialization parameter for memories A and B 
- Pd: Detector dark count probability per photonic mode (assumed to be the same for both detectors)
- Vis: Interferometer visibility for the midpoint swap 

```jldoctest
julia> r = Register(2)

julia> initialize!(r[1:2], DualRailMidSwapBellN(0.9, 0.9, 0.5, 0.5, 1e-8, 0.99))

julia> observable(r[1:2], Z⊗Z)
```
"""
@withmetadata struct DualRailMidSwapBellN <: AbstractTwoQubitState
    eA::Float64
    eB::Float64
    gA::Float64
    gB::Float64
    Pd::Float64
    Vis::Float64
end

symbollabel(x::DualRailMidSwapBellN) = "ρᵈʳᵐˢᴺ"


## express

function express_nolookup(x::SingleRailMidSwapBellU, ::QuantumOpticsRepr)
    data = midswap_single_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data))
end

function express_nolookup(x::SingleRailMidSwapBellN, ::QuantumOpticsRepr)
    data = midswap_single_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data/tr(data)))
end

function express_nolookup(x::DualRailMidSwapBellU, ::QuantumOpticsRepr)
    data = midswap_dual_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data))
end

function express_nolookup(x::DualRailMidSwapBellN, ::QuantumOpticsRepr)
    data = midswap_dual_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data/tr(data)))
end

## trace

tr(x::SingleRailMidSwapBellU) = Float64(tr(express(x).data))
tr(x::DualRailMidSwapBellU) = Float64(tr(express(x).data))