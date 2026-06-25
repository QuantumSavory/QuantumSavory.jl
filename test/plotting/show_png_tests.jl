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

# qTCP controller PNG smoke tests
net2 = RegisterNet([reg1, reg2, reg1])
sim2 = get_time_tracker(net2)
end_controller = QuantumSavory.ProtocolZoo.EndNodeController(sim2, net2, 1)
network_controller = QuantumSavory.ProtocolZoo.NetworkNodeController(sim2, net2, 2)
link_controller = QuantumSavory.ProtocolZoo.LinkController(sim2, net2, 1, 2)
show(out, MIME"image/png"(), end_controller)
show(out, MIME"image/png"(), network_controller)
show(out, MIME"image/png"(), link_controller)

reg1 = Register([Qumode()], [GabsRepr(QuadBlockBasis)])
initialize!(reg1[1], SqueezedState(0.8))
apply!(reg1[1], DisplaceOp(0.6 - 0.4im))
show(out, MIME"image/png"(), QuantumSavory.stateof(reg1[1]))


reg2 = Register([Qumode(), Qumode()], [GabsRepr(QuadBlockBasis), GabsRepr(QuadBlockBasis)])
initialize!(reg2[1:2], TwoSqueezedState(0.45))
show(out, MIME"image/png"(), QuantumSavory.stateof(reg2[1]))

end
