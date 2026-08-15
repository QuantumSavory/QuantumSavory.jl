using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using Gabs
using CairoMakie
import InteractiveUtils, REPL

@testset "show image/png" begin

#out = stdout
out = IOBuffer()

reg = Register([Qubit(), Qumode()], [CliffordRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])

initialize!(reg[1], X1)

#show(out, MIME"image/png"(), reg[1])
#show(out, MIME"image/png"(), reg[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg[1]))

reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

#show(out, MIME"image/png"(), reg1[1])
#show(out, MIME"image/png"(), reg2[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


reg1 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
reg2 = Register([Qubit(), Qumode()], [QuantumOpticsRepr(), QuantumOpticsRepr()], [PauliNoise(0.1,0.1,0.1),AmplitudeDamping(0.2)])
net = RegisterNet([reg1, reg2]; name="my net", names=["reg 1", "reg 2"])

initialize!((reg1[1],reg2[1]), X1⊗Z1+Z1⊗X1)

#show(out, MIME"image/png"(), reg1[1])
#show(out, MIME"image/png"(), reg2[2])
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


prot = EntanglerProt(get_time_tracker(net), net, 1, 2)
show(out, MIME"image/png"(), prot)

makie_extension = Base.get_extension(QuantumSavory, :QuantumSavoryMakie)
@test makie_extension.protshowrows(EntanglementTracker(net, 1)) == 1
@test makie_extension.protshowrows(prot) == 2
@test makie_extension.protshowrows(EntanglementConsumer(net, 1, 2)) == 2
@test makie_extension._geometric_tail_cutoff(1.0) == 1
@test makie_extension._geometric_tail_cutoff(0.5) == 10
@test makie_extension._geometric_tail_cutoff(0.001) == 6905

link_controller = LinkController(get_time_tracker(net), net, 1, 2)
@test makie_extension.protshowrows(link_controller) == 4
empty_link_png = repr(MIME"image/png"(), link_controller)
append!(link_controller._log, [
    (originator_node=1, arrival_time=1.0, sojourn_time=2.0),
    (originator_node=2, arrival_time=2.0, sojourn_time=4.0),
    (originator_node=1, arrival_time=5.0, sojourn_time=nothing),
    (originator_node=2, arrival_time=8.0, sojourn_time=6.0),
    (originator_node=1, arrival_time=9.0, sojourn_time=8.0),
    (originator_node=2, arrival_time=14.0, sojourn_time=10.0),
])
populated_link_png = repr(MIME"image/png"(), link_controller)
png_signature = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

@test first(empty_link_png, 8) == png_signature
@test first(populated_link_png, 8) == png_signature
@test empty_link_png != populated_link_png


reg1 = Register([Qumode()], [GabsRepr(QuadBlockBasis)])
initialize!(reg1[1], SqueezedState(0.8))
apply!(reg1[1], DisplaceOp(0.6 - 0.4im))
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


reg2 = Register([Qumode(), Qumode()], [GabsRepr(QuadBlockBasis), GabsRepr(QuadBlockBasis)])
initialize!(reg2[1:2], TwoSqueezedState(0.45))
show(out, MIME"image/png"(), QuantumSavory.stateof(reg2[1]))

end
