using Test
using QuantumSavory
using QuantumClifford
using QuantumOptics
using QuantumSavory: _h, _l, _s₊, _s₋, _i₊, _i₋
using LinearAlgebra

for n in 1:5
    stabs = [random_stabilizer(1) for _ in 1:n]
    stab = reduce(QuantumClifford.tensor, stabs)
    translate = Dict(S"X"=>_s₊,S"-X"=>_s₋,S"Z"=>_l,S"-Z"=>_h,S"Y"=>_i₊,S"-Y"=>_i₋)
    kets = [translate[s] for s in stabs]
    ket = reduce(QuantumOptics.tensor, kets)
    @test ket.data ≈ stab_to_ket(stab).data

    rstab = random_stabilizer(n)
    lstab = random_stabilizer(n)
    lket = stab_to_ket(rstab)
    rket = stab_to_ket(lstab)
    dotket = abs(lket'*rket)
    dotstab = abs(dot(lstab,rstab))
    @test (dotket<=1e-10 && dotstab==0) || dotket≈dotstab
end
