@testitem "show image/png" tags=[:plotting_cairo] begin
using Test
using QuantumSavory
using QuantumSavory.ProtocolZoo
using CairoMakie
import InteractiveUtils, REPL

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

end
