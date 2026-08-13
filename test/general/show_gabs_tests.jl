using Test
using QuantumSavory
using Gabs

@testset "show gabs text/plain" begin

reg1 = Register([Qumode()], [GabsRepr(QuadPairBasis)])
initialize!(reg1[1], CoherentState(0.2 - 0.5im))
apply!(reg1[1], DisplaceOp(0.6 - 0.4im))
output = sprint(show, MIME"text/plain"(), QuantumSavory.stateof(reg1[1]))
@test occursin("Gaussian State", output)
@test occursin("Modes: 1", output)
@test occursin("Purity: 1.0", output)
@test occursin("Covariance Matrix", output)


reg2 = Register([Qumode(), Qumode()], [GabsRepr(QuadBlockBasis), GabsRepr(QuadBlockBasis)])
initialize!(reg2[1:2], TwoSqueezedState(0.45))
apply!(reg2[1], DisplaceOp(0.6 - 0.4im))
output = sprint(show, MIME"text/plain"(), QuantumSavory.stateof(reg2[1]))
@test occursin("Gaussian State", output)
@test occursin("Modes: 2", output)
@test occursin("Displacement Vector (First Moments)", output)
@test occursin("Per-mode Marginals", output)


reg2 = Register([Qumode(), Qumode()], [GabsRepr(QuadPairBasis), GabsRepr(QuadPairBasis)])
initialize!(reg2[1:2], TwoSqueezedState(0.45))
output = sprint(show, MIME"text/plain"(), QuantumSavory.stateof(reg2[1]))
@test !occursin("Displacement Vector (First Moments)", output)

end
