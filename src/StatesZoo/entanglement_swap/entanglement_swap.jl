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

@withmetadata struct SingleRailMidSwapBell <: AbstractTwoQubitState
    eA::Float64
    eB::Float64
    gA::Float64
    gB::Float64
    Pd::Float64
    Vis::Float64
end

symbollabel(x::SingleRailMidSwapBell) = "ρˢʳᵐˢ"

@withmetadata struct DualRailMidSwapBell <: AbstractTwoQubitState
    eA::Float64
    eB::Float64
    gA::Float64
    gB::Float64
    Pd::Float64
    Vis::Float64
end

symbollabel(x::DualRailMidSwapBell) = "ρᵈʳᵐˢ"


## express

function express_nolookup(x::SingleRailMidSwapBell, ::QuantumOpticsRepr)
    data = midswap_single_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data))
end

function express_nolookup(x::DualRailMidSwapBell, ::QuantumOpticsRepr)
    data = midswap_dual_rail(x.eA, x.eB, x.gA, x.gB, x.Pd, x.Vis)
    return SparseOperator(_bspin⊗_bspin, Complex.(data))
end